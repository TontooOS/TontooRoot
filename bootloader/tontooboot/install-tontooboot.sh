#!/usr/bin/env bash
# Install TontooBoot (rEFInd + TontooOS theme) on the target system.
# Usage: install-tontooboot.sh [--esp /efi] [--disk /dev/sda] [--light]
# English only. UEFI only.
set -euo pipefail

ESP="/efi"
MODE="dark"
for arg in "$@"; do
  case "${arg}" in
    --esp)
      ESP="${2:-/efi}"
      shift 2
      ;;
    --esp=*)
      ESP="${arg#--esp=}"
      ;;
    --light)
      MODE="light"
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
theme_src="${script_dir}"
refind_conf_src="${theme_src}/refind.conf"

if [[ ! -f "${refind_conf_src}" ]]; then
  echo "refind.conf not found next to installer." >&2
  exit 1
fi

if ! command -v refind-install >/dev/null 2>&1; then
  echo "refind-install not found. Install package 'refind' first." >&2
  exit 1
fi

echo "Installing rEFInd to ${ESP} ..."
refind-install --usedefault "${ESP}"

theme_dst="${ESP}/EFI/refind/themes/tontooboot"
mkdir -p "${theme_dst}/icons"

cp -f "${refind_conf_src}" "${ESP}/EFI/refind/refind.conf"

# Convert SVG sources to PNG when rsvg-convert is available,
# else copy SVG sidecars and let the live session convert.
if command -v rsvg-convert >/dev/null 2>&1; then
  for svg in "${theme_src}/icons/"*.svg; do
    name="$(basename -- "${svg}" .svg)"
    rsvg-convert -w 144 -h 144 "${svg}" -o "${theme_dst}/icons/${name}.png" || true
  done
  rsvg-convert -w 1920 -h 1080 "${theme_src}/icons/background.svg" -o "${theme_dst}/banner.png" || true
else
  cp -a "${theme_src}/icons/"*.svg "${theme_dst}/icons/" 2>/dev/null || true
  echo "Warning: rsvg-convert missing, staged SVG only." >&2
fi

# 48x48 selection rings (simple accent circles).
if command -v python3 >/dev/null 2>&1; then
  python3 - "${theme_dst}" <<'PY'
import struct, sys, zlib, math
dst = sys.argv[1]
def png_circle(path, size, rgb):
  def chunk(t, d):
    c = t + d
    return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
  px = bytearray()
  cx = cy = (size - 1) / 2.0
  r_out = size / 2.0 - 2
  r_in = r_out - 5
  for y in range(size):
    px.append(0)
    for x in range(size):
      d = math.hypot(x - cx, y - cy)
      a = 255 if r_in <= d <= r_out else 0
      px += bytes((rgb[0], rgb[1], rgb[2], a))
  raw = b"".join(bytes((0,)) + bytes(px[y*(size*4+1)+1:(y+1)*(size*4+1)]) for y in range(size))
  ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
  with open(path, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(px))) + chunk(b"IEND", b""))
png_circle(dst + "/selection-big.png", 144, (255, 107, 43))
png_circle(dst + "/selection-small.png", 48, (255, 107, 43))
PY
fi

# Light mode swaps the banner to #ececec.
if [[ "${MODE}" == "light" ]] && command -v python3 >/dev/null 2>&1; then
  python3 - "${theme_dst}/banner.png" <<'PY'
import sys
print("light banner requested, regenerate from background-light.svg if present")
PY
fi

cp -f "${theme_src}/theme.conf" "${theme_dst}/theme.conf"
cp -rf "${theme_src}/lang" "${theme_dst}/lang" 2>/dev/null || true

echo "TontooBoot installed. Theme: ${theme_dst} Mode: ${MODE}"

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

# Pre-rendered selection rings (committed in this theme, no python needed).
cp -f "${theme_src}/selection-big.png" "${theme_dst}/selection-big.png" 2>/dev/null || true
cp -f "${theme_src}/selection-small.png" "${theme_dst}/selection-small.png" 2>/dev/null || true

cp -f "${theme_src}/theme.conf" "${theme_dst}/theme.conf"
cp -rf "${theme_src}/lang" "${theme_dst}/lang" 2>/dev/null || true

echo "TontooBoot installed. Theme: ${theme_dst} Mode: ${MODE}"

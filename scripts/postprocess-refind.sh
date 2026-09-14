#!/usr/bin/env bash
# Post-process the ISO: replace GRUB in efiboot.img with rEFInd (TontooBoot).
# Usage: postprocess-refind.sh <iso-file> <archiso-uuid> [theme-dir]
# Requires: mtools, fdisk, sfdisk, dd.
set -euo pipefail

iso_file="${1:-}"
archiso_uuid="${2:-}"
theme_dir="${3:-}"

if [[ -z "$iso_file" || ! -f "$iso_file" ]]; then
  echo "Usage: postprocess-refind.sh <iso-file> <archiso-uuid> [theme-dir]" >&2
  exit 1
fi

if [[ -z "$archiso_uuid" ]]; then
  echo "Error: archiso_uuid is required." >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
refind_conf_src="${base_dir}/BaseOS/archiso/refind/refind-live.conf"

if [[ ! -f "$refind_conf_src" ]]; then
  echo "refind-live.conf not found at ${refind_conf_src}" >&2
  exit 1
fi

if [[ -z "$theme_dir" ]]; then
  theme_dir="${base_dir}/BaseOS/bootloader/tontooboot"
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

echo "==> Extracting efiboot partition from ISO..."

# Find partition 2 (EFI system partition) offset and size
part_info="$(sfdisk -d "$iso_file" 2>/dev/null | grep "${iso_file}2" || true)"
if [[ -z "$part_info" ]]; then
  echo "Error: partition 2 not found in ${iso_file}" >&2
  exit 1
fi

start_sector="$(echo "$part_info" | sed -E 's/.*start=\s*([0-9]+).*/\1/')"
size_sectors="$(echo "$part_info" | sed -E 's/.*size=\s*([0-9]+).*/\1/')"

if [[ -z "$start_sector" || -z "$size_sectors" ]]; then
  echo "Error: could not parse partition layout." >&2
  exit 1
fi

echo "  Partition 2: start=${start_sector} size=${size_sectors} sectors"

# Extract the efiboot partition
efiboot_img="${work_dir}/efiboot.img"
dd if="$iso_file" of="$efiboot_img" bs=512 skip="$start_sector" count="$size_sectors" status=progress 2>/dev/null

echo "==> Replacing GRUB with rEFInd..."

# Mount the FAT image
mnt_dir="${work_dir}/efi"
mkdir -p "$mnt_dir"
mount -o loop "$efiboot_img" "$mnt_dir"

# Remove GRUB files
rm -rf "${mnt_dir}/EFI/BOOT" 2>/dev/null || true
rm -rf "${mnt_dir}/EFI/refind" 2>/dev/null || true
rm -rf "${mnt_dir}/arch" 2>/dev/null || true

# Create rEFInd directory structure
mkdir -p "${mnt_dir}/EFI/BOOT"
mkdir -p "${mnt_dir}/EFI/refind/drivers_x64"
mkdir -p "${mnt_dir}/EFI/refind/themes/tontooboot/icons"

# Copy rEFInd binary
cp -f "/usr/share/refind/refind_x64.efi" "${mnt_dir}/EFI/BOOT/BOOTx64.EFI"

# Copy iso9660 driver
cp -f "/usr/share/refind/drivers_x64/iso9660_x64.efi" "${mnt_dir}/EFI/refind/drivers_x64/"

# Copy theme icons (from the bootloader source, converted to PNG earlier)
for svg in "${theme_dir}/icons/"*.svg; do
  [[ -e "$svg" ]] || continue
  name="$(basename -- "$svg" .svg)"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 144 -h 144 "$svg" -o "${mnt_dir}/EFI/refind/themes/tontooboot/icons/${name}.png" || true
  fi
done

# Copy theme banner
if [[ -f "${theme_dir}/icons/background.svg" ]] && command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 1920 -h 1080 "${theme_dir}/icons/background.svg" -o "${mnt_dir}/EFI/refind/themes/tontooboot/banner.png" || true
fi

# Copy selection rings
if command -v python3 >/dev/null 2>&1; then
  python3 - "${mnt_dir}/EFI/refind/themes/tontooboot" <<'PY'
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
PY
fi

# Generate refind.conf from template with real UUID
sed "s/%ARCHISO_UUID%/${archiso_uuid}/g" "$refind_conf_src" > "${mnt_dir}/EFI/refind/refind.conf"

echo "  Installed files:"
find "${mnt_dir}" -type f | sed "s|${mnt_dir}/||"

# Unmount
umount "$mnt_dir"

echo "==> Writing modified efiboot partition back to ISO..."
dd if="$efiboot_img" of="$iso_file" bs=512 seek="$start_sector" count="$size_sectors" conv=notrunc status=progress 2>/dev/null

echo "==> TontooBoot ISO patch complete."

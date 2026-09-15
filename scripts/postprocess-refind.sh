#!/usr/bin/env bash
# Post-process the ISO: replace GRUB in efiboot.img with rEFInd (TontooBoot).
# Usage: postprocess-refind.sh <iso-file> <archiso-uuid> [theme-dir]
# Requires: mtools (mcopy, mmd, mdir), sfdisk, dd, python3.
# Does NOT require root — uses mtools for FAT manipulation.
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

for cmd in sfdisk dd mcopy mmd mdir python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
done

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

iso_basename="$(basename -- "$iso_file")"
part_info="$(sfdisk -d "$iso_file" 2>/dev/null | grep "${iso_basename}2" || true)"
if [[ -z "$part_info" ]]; then
  echo "Error: partition 2 not found in ${iso_file}" >&2
  echo "  sfdisk output:" >&2
  sfdisk -d "$iso_file" 2>/dev/null >&2
  exit 1
fi

start_sector="$(echo "$part_info" | sed -E 's/.*start=\s*([0-9]+).*/\1/')"
size_sectors="$(echo "$part_info" | sed -E 's/.*size=\s*([0-9]+).*/\1/')"

if [[ -z "$start_sector" || -z "$size_sectors" ]]; then
  echo "Error: could not parse partition layout." >&2
  echo "  Raw: $part_info" >&2
  exit 1
fi

echo "  Partition 2: start=${start_sector} size=${size_sectors} sectors"

efiboot_img="${work_dir}/efiboot.img"
dd if="$iso_file" of="$efiboot_img" bs=512 skip="$start_sector" count="$size_sectors" 2>/dev/null

echo "==> Listing current efiboot contents..."
mdir -i "$efiboot_img" ::/EFI/BOOT/ 2>/dev/null || echo "  (no EFI/BOOT)"

echo "==> Generating PNG assets with python3..."

python3 - "$work_dir" "$theme_dir" <<'PY'
import struct, sys, zlib, math, os

work = sys.argv[1]
theme = sys.argv[2]
icons_dst = os.path.join(work, "icons")
os.makedirs(icons_dst, exist_ok=True)

def make_png_circle(path, size, rgb):
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    px = bytearray()
    cx = cy = (size - 1) / 2.0
    r_out = size / 2.0 - 2
    r_in = max(r_out - 5, 0)
    for y in range(size):
        px.append(0)
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            a = 255 if r_in <= d <= r_out else 0
            px += bytes((rgb[0], rgb[1], rgb[2], a))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(px))) + chunk(b"IEND", b""))

def make_png_solid(path, w, h, rgb):
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    px = bytearray()
    for y in range(h):
        px.append(0)
        px += bytes(rgb) * w
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(px))) + chunk(b"IEND", b""))

def make_png_os_icon(path, size):
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    px = bytearray()
    cx = cy = (size - 1) / 2.0
    r = size / 2.0 - 4
    for y in range(size):
        px.append(0)
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                if d <= r - 12:
                    px += bytes((255, 107, 43))
                elif d <= r - 6:
                    px += bytes((43, 43, 43))
                else:
                    px += bytes((255, 107, 43))
            else:
                px += bytes((0, 0, 0))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(px))) + chunk(b"IEND", b""))

def make_png_recovery_icon(path, size):
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    px = bytearray()
    cx = cy = (size - 1) / 2.0
    r = size / 2.0 - 4
    for y in range(size):
        px.append(0)
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                if d <= r - 14:
                    px += bytes((43, 43, 43))
                elif d <= r - 8:
                    px += bytes((255, 107, 43))
                else:
                    px += bytes((43, 43, 43))
            else:
                px += bytes((0, 0, 0))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(px))) + chunk(b"IEND", b""))

banner = os.path.join(work, "banner.png")
make_png_solid(banner, 1920, 1080, (29, 29, 29))
print(f"  banner.png (1920x1080, #1d1d1d)")

sel = os.path.join(work, "selection-big.png")
make_png_circle(sel, 144, (255, 107, 43))
print(f"  selection-big.png (144x144, orange ring)")

os_tontoo = os.path.join(icons_dst, "os_tontoo.png")
make_png_os_icon(os_tontoo, 144)
print(f"  icons/os_tontoo.png")

tool_recovery = os.path.join(icons_dst, "tool_recovery.png")
make_png_recovery_icon(tool_recovery, 144)
print(f"  icons/tool_recovery.png")
PY

echo "==> Building new efiboot image with rEFInd..."

# Create a fresh FAT image (same size as original)
mkefi_img="${work_dir}/new_efiboot.img"
cp "$efiboot_img" "$mkefi_img"

# Wipe existing content by recreating
dd if=/dev/zero of="$mkefi_img" bs=512 count="$size_sectors" 2>/dev/null
mkfs.fat -F 32 -n REFINDBOOT "$mkefi_img" 2>/dev/null

# Create directory structure
mmd -i "$mkefi_img" ::/EFI
mmd -i "$mkefi_img" ::/EFI/BOOT
mmd -i "$mkefi_img" ::/EFI/refind
mmd -i "$mkefi_img" ::/EFI/refind/drivers_x64
mmd -i "$mkefi_img" ::/EFI/refind/themes
mmd -i "$mkefi_img" ::/EFI/refind/themes/tontooboot
mmd -i "$mkefi_img" ::/EFI/refind/themes/tontooboot/icons

# Copy rEFInd binary
echo "  Copying refind_x64.efi..."
mcopy -i "$mkefi_img" "/usr/share/refind/refind_x64.efi" ::/EFI/BOOT/BOOTx64.EFI

# Copy iso9660 driver
echo "  Copying iso9660 driver..."
mcopy -i "$mkefi_img" "/usr/share/refind/drivers_x64/iso9660_x64.efi" ::/EFI/refind/drivers_x64/

# Copy theme assets
echo "  Copying theme assets..."
mcopy -i "$mkefi_img" "${work_dir}/banner.png" ::/EFI/refind/themes/tontooboot/banner.png
mcopy -i "$mkefi_img" "${work_dir}/selection-big.png" ::/EFI/refind/themes/tontooboot/selection-big.png
mcopy -i "$mkefi_img" "${work_dir}/icons/os_tontoo.png" ::/EFI/refind/themes/tontooboot/icons/os_tontoo.png
mcopy -i "$mkefi_img" "${work_dir}/icons/tool_recovery.png" ::/EFI/refind/themes/tontooboot/icons/tool_recovery.png

# Generate and copy refind.conf
echo "  Writing refind.conf (UUID=${archiso_uuid})..."
sed "s/%ARCHISO_UUID%/${archiso_uuid}/g" "$refind_conf_src" > "${work_dir}/refind.conf"
mcopy -i "$mkefi_img" "${work_dir}/refind.conf" ::/EFI/refind/refind.conf

echo "  New efiboot contents:"
mdir -i "$mkefi_img" ::/EFI/BOOT/
mdir -i "$mkefi_img" ::/EFI/refind/
mdir -i "$mkefi_img" ::/EFI/refind/themes/tontooboot/

echo "==> Writing modified efiboot partition back to ISO..."
dd if="$mkefi_img" of="$iso_file" bs=512 seek="$start_sector" count="$size_sectors" conv=notrunc 2>/dev/null

echo "==> TontooBoot ISO patch complete."

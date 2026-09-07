#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
profile_dir="${base_dir}/BaseOS/archiso"
vendor_dir="${base_dir}/ai_temp_filees/MacTahoe-gtk-theme"
themes_dest="${profile_dir}/airootfs/usr/share/themes"

if [[ ! -d "${vendor_dir}" ]]; then
    echo "MacTahoe theme vendor directory not found at ${vendor_dir}" >&2
    exit 1
fi

echo "==> Installing MacTahoe GTK Theme (all variants, blur, libadwaita)..."

# Install GTK themes into the ISO filesystem
# Note: -c, -o, -s don't accept 'all' - must pass each variant separately
# -t and -a do accept 'all'
mkdir -p "${themes_dest}"

cd "${vendor_dir}"

# Fix CRLF in all vendor scripts (NTFS/WSL compat)
find "${vendor_dir}" -name '*.sh' -exec sed -i 's/\r$//' {} + 2>/dev/null || true

# We only need GTK themes, not GNOME Shell themes. Make install_shelly a no-op
# so sassc doesn't try to compile gnome-shell CSS (which fails without gnome-shell)
perl -i -pe 's/^install_shelly\(\) \{/install_shelly() { return; } # KDE: no GNOME Shell/' \
    "${vendor_dir}/libs/lib-install.sh"

# Install theme variants (not ALL 72 combos - too slow on NTFS)
# Default dark + light with blue accent, blur version
bash install.sh \
    --silent-mode \
    --dest "${themes_dest}" \
    -c dark \
    -t blue \
    -b \
    --round

bash install.sh \
    --silent-mode \
    --dest "${themes_dest}" \
    -c light \
    -t blue \
    -b \
    --round

echo "  -> MacTahoe GTK themes installed to ${themes_dest}"

echo "==> MacTahoe theme staged successfully"

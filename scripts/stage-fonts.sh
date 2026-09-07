#!/usr/bin/env bash
# Stage SF Pro system fonts into the ISO airootfs.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
profile_dir="${base_dir}/BaseOS/archiso"
fonts_otf_dir="${profile_dir}/airootfs/usr/share/fonts/OTF"
fonts_ttf_dir="${profile_dir}/airootfs/usr/share/fonts/TTF"

# Remove stale font directories so we always have a clean set
rm -rf "${fonts_otf_dir}" "${fonts_ttf_dir}"
mkdir -p "${fonts_otf_dir}" "${fonts_ttf_dir}"

# Copy the SF Pro OTF font files (these are the individual weights)
cp -a "${base_dir}/BaseOS/fonts/SF-Pro/"*.otf "${fonts_otf_dir}/" 2>/dev/null || {
  echo "Warning: no .otf font files found in BaseOS/fonts/SF-Pro/" >&2
}

# Copy the SF Pro TTF variable fonts
cp -a "${base_dir}/BaseOS/fonts/SF-Pro/"*.ttf "${fonts_ttf_dir}/" 2>/dev/null || {
  echo "Warning: no .ttf font files found in BaseOS/fonts/SF-Pro/" >&2
}

echo "Staged SF Pro fonts -> /usr/share/fonts/OTF/ ($(ls -1 "${fonts_otf_dir}" | wc -l) files)"
echo "Staged SF Pro fonts -> /usr/share/fonts/TTF/ ($(ls -1 "${fonts_ttf_dir}" | wc -l) files)"

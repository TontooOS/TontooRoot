#!/usr/bin/env bash
# Stage TontooBoot (rEFInd theme + installer) into the ISO airootfs.
set -euo pipefail

GITHUB_ACTIONS_BUILD=0
for arg in "$@"; do
  case "${arg}" in
    --github-actions)
      GITHUB_ACTIONS_BUILD=1
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
src_dir="${base_dir}/BaseOS/bootloader/tontooboot"
profile_dir="${base_dir}/BaseOS/archiso"
theme_dst="${profile_dir}/airootfs/usr/share/tontooboot"
setup_dst="${profile_dir}/airootfs/usr/local/lib/baseos-setup/install-tontooboot.sh"

if [[ ! -d "${src_dir}" ]]; then
  echo "TontooBoot source not found at ${src_dir}." >&2
  exit 1
fi

rm -rf "${theme_dst}"
mkdir -p "${theme_dst}/icons" "$(dirname -- "${setup_dst}")"

cp -f "${src_dir}/refind.conf" "${theme_dst}/"
cp -f "${src_dir}/theme.conf" "${theme_dst}/"
cp -f "${src_dir}/README.md" "${theme_dst}/" 2>/dev/null || true
cp -a "${src_dir}/icons/." "${theme_dst}/icons/"
cp -a "${src_dir}/lang" "${theme_dst}/" 2>/dev/null || true
cp -f "${src_dir}/install-tontooboot.sh" "${setup_dst}"
chmod 0755 "${setup_dst}" "${theme_dst}/../tontooboot" 2>/dev/null || true
chmod 0755 "${setup_dst}"

echo "Staged TontooBoot -> /usr/share/tontooboot"

#!/usr/bin/env bash
set -euo pipefail

# Accepts --github-actions (forwarded by build-iso.sh). Wallpaper sources
# live inside this repo, so this script needs no path changes.
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
wallpapers_dir="${base_dir}/BaseOS/wallpapers"
profile_dir="${base_dir}/BaseOS/archiso"
target_dir="${profile_dir}/airootfs/usr/share/tontoo/wallpapers"

if [[ ! -d "${wallpapers_dir}" ]]; then
  echo "Wallpapers directory not found at ${wallpapers_dir}." >&2
  exit 1
fi

rm -rf "${target_dir}"
mkdir -p "${target_dir}"

shopt -s dotglob nullglob
for category_dir in "${wallpapers_dir}"/*/; do
  category="$(basename -- "${category_dir}")"
  dest_category="${target_dir}/${category}"
  mkdir -p "${dest_category}"

  for item in "${category_dir}"*; do
    name="$(basename -- "${item}")"
    case "${name}" in
      ".git"|".gitignore")
        continue
        ;;
    esac
    cp -a "${item}" "${dest_category}/"
  done
done

echo "Staged wallpapers -> /usr/share/tontoo/wallpapers"
echo "  Categories: $(ls -1 "${target_dir}" | tr '\n' ' ')"

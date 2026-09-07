#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
repo_dir="${base_dir}"
library_dir="${repo_dir}/LiquidLibarie"
profile_dir="${base_dir}/BaseOS/archiso"
package_dir="${profile_dir}/airootfs/usr/local/lib/node_modules/@tontoo-os/liquid-glass"

if [[ ! -d "${library_dir}" ]]; then
  echo "LiquidLibarie was not found at ${library_dir}." >&2
  exit 1
fi

if [[ ! -f "${library_dir}/dist/components.js" ]]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "LiquidLibarie/dist is missing and npm is not available to build it." >&2
    exit 1
  fi

  (
    cd "${library_dir}"
    # Use --no-package-lock to avoid Windows lockfile being used on Linux
    npm install --no-package-lock
    npm run build
  )
fi

if [[ ! -f "${library_dir}/dist/components.js" ]]; then
  echo "LiquidLibarie build did not create dist/components.js." >&2
  exit 1
fi

case "${package_dir}" in
  "${profile_dir}/airootfs/"*) ;;
  *)
    echo "Refusing to stage LiquidLibarie outside the archiso airootfs." >&2
    exit 1
    ;;
esac

rm -rf "${package_dir}"
mkdir -p "${package_dir}"
cp -a "${library_dir}/dist" "${package_dir}/dist"
cp -a "${library_dir}/package.json" "${package_dir}/package.json"
cp -a "${library_dir}/README.md" "${package_dir}/README.md"
if [[ -d "${library_dir}/docs" ]]; then
  cp -a "${library_dir}/docs" "${package_dir}/docs"
fi

echo "Staged LiquidLibarie as global package: /usr/local/lib/node_modules/@tontoo-os/liquid-glass"

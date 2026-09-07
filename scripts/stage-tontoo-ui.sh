#!/usr/bin/env bash
# Copy the TontooUI library source into the live ISO airootfs
# at /Libraries/TontooUI/ for system-wide development access.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
tontoo_ui_dir="${base_dir}/TontooUI"
lib_dest="${base_dir}/BaseOS/archiso/airootfs/Libraries/TontooUI"

if [[ ! -d "${tontoo_ui_dir}" ]]; then
  echo "stage-tontoo-ui: TontooUI source not found at ${tontoo_ui_dir}" >&2
  exit 0
fi

echo "==> Copying TontooUI library source -> ${lib_dest}"
mkdir -p "${lib_dest}/src"
cp -r "${tontoo_ui_dir}/src" "${lib_dest}/"
cp "${tontoo_ui_dir}/Cargo.toml" "${lib_dest}/"
cp "${tontoo_ui_dir}/Cargo.lock" "${lib_dest}/" 2>/dev/null || true
cp "${tontoo_ui_dir}/build.rs" "${lib_dest}/" 2>/dev/null || true
cp "${tontoo_ui_dir}/tontoo_ui.xml" "${lib_dest}/" 2>/dev/null || true
cp "${tontoo_ui_dir}/AGENTS.md" "${lib_dest}/" 2>/dev/null || true
cp "${tontoo_ui_dir}/ELEM.md" "${lib_dest}/" 2>/dev/null || true
cp "${tontoo_ui_dir}/LIQUID_GLASS_DEFAULTS.md" "${lib_dest}/" 2>/dev/null || true
cp -r "${tontoo_ui_dir}/Assets" "${lib_dest}/" 2>/dev/null || true
cp -r "${tontoo_ui_dir}/examples" "${lib_dest}/" 2>/dev/null || true
echo "==> TontooUI library -> ${lib_dest}"

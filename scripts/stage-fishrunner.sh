#!/usr/bin/env bash
# Build the tapp app runner (FishRunner) and stage it into the live ISO airootfs
# at /usr/bin/tapp. tapp launches .app bundles; together with the staged
# binfmt_misc registration (tapp-binfmt LaunchPad) executing any ".app" file
# directly dispatches to the runner.
#
# This must run on Linux with the Rust toolchain. build-iso.sh invokes it
# before mkarchiso.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
runner_dir="${FISHRUNNER_DIR:-${base_dir}/../TontooProgramms/FishRunner}"
dest_dir="${base_dir}/BaseOS/archiso/airootfs/usr/bin"

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-fishrunner: cargo not found; skipping tapp build" >&2
  exit 0
fi

if [[ ! -d "${runner_dir}" ]]; then
  echo "stage-fishrunner: FishRunner directory not found at ${runner_dir}" >&2
  exit 0
fi

echo "==> Building tapp (FishRunner)..."
cd "${runner_dir}"
cargo build --release

mkdir -p "${dest_dir}"
cp -f "${runner_dir}/target/release/tapp" "${dest_dir}/tapp"
chmod 0755 "${dest_dir}/tapp"
echo "==> tapp -> ${dest_dir}"

lang_dest="${base_dir}/BaseOS/archiso/airootfs/usr/share/tapp/lang"
mkdir -p "${lang_dest}"
cp -f "${runner_dir}/lang/en_us.json" "${lang_dest}/en_us.json"
cp -f "${runner_dir}/lang/de_de.json" "${lang_dest}/de_de.json"
chmod 0644 "${lang_dest}/en_us.json" "${lang_dest}/de_de.json"
echo "==> tapp lang -> ${lang_dest}"

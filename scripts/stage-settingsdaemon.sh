#!/usr/bin/env bash
# Build the TontooOS Settings daemon (Rust) and stage it into the live ISO
# airootfs as a bundle at /System/Daemons/Settings.app, started at boot via
# the `SettingsDaemon` LaunchPad service (System/services/SettingsDaemon.service
# -> start-settingsdaemon.sh -> tapp), like menubar/dock.
#
# Layout mirrors the TBuild .app bundles (App/<binary>, Info.tontoo):
#   /System/Daemons/Settings.app/App/settings-daemon
#   /System/Daemons/Settings.app/Info.tontoo
#
# This must run on Linux with the Rust toolchain. build-iso.sh invokes it
# before mkarchiso so LaunchPad (PID 1) starts the daemon on boot.
set -euo pipefail

# Accepts --github-actions (forwarded by build-iso.sh). In that mode all
# external sources are pre-cloned to the standard local paths, so this
# script needs no path changes.
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
profile_dir="${base_dir}/BaseOS/archiso"
daemon_dir=""
for candidate in \
  "${base_dir}/../TontooServices/SettingsDeamon" \
  "${base_dir}/TontooServices/SettingsDeamon" \
  "${SETTINGSDAEMON_DIR:-/nonexistent}"; do
  if [[ -f "${candidate}/Cargo.toml" ]]; then
    daemon_dir="${candidate}"
    break
  fi
done
dest_dir="${profile_dir}/airootfs/System/Daemons/Settings.app"
service_file="${profile_dir}/airootfs/System/services/SettingsDaemon.service"

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-settingsdaemon: cargo not found; skipping SettingsDaemon build" >&2
  exit 0
fi

if [[ -z "${daemon_dir}" ]]; then
  echo "stage-settingsdaemon: SettingsDeamon directory not found; skipping build" >&2
  exit 0
fi

echo "==> Building SettingsDaemon..."
cd "${daemon_dir}"
cargo build --release --bin settings-daemon

if [[ ! -f "${daemon_dir}/target/release/settings-daemon" ]]; then
  echo "WARNING: stage-settingsdaemon: settings-daemon was not built, skipping." >&2
  exit 0
fi

# --- Assemble the daemon bundle (TBuild .app layout) ---
rm -rf "${dest_dir}"
mkdir -p "${dest_dir}/App"
cp -f "${daemon_dir}/target/release/settings-daemon" "${dest_dir}/App/settings-daemon"
chmod 0755 "${dest_dir}/App/settings-daemon"
# Bundle metadata follows the daemon crate version (never hardcoded:
# versions are owned by the component repos).
daemon_version="$(grep -m1 '^version' "${daemon_dir}/Cargo.toml" | sed -E 's/.*\"([^\"]+)\".*/\1/')"
daemon_version="${daemon_version:-26.1.0}"
cat > "${dest_dir}/Info.tontoo" <<EOF
{
  "bundle_id": "com.tontoo.settingsdaemon",
  "name": "SettingsDaemon",
  "version": "${daemon_version}"
}
EOF
chmod 0755 "${dest_dir}" 2>/dev/null || true
echo "==> Settings.app bundle -> ${dest_dir}"

# The LaunchPad service definition is committed in airootfs (same as
# menubar.service); just verify it is there.
if [[ -f "${service_file}" ]]; then
  echo "==> SettingsDaemon.service present"
else
  echo "WARNING: stage-settingsdaemon: ${service_file} not found; daemon will not start." >&2
fi

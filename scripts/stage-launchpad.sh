#!/usr/bin/env bash
# Build the LaunchPad daemon and launchctl CLI, then place the binaries
# into the live ISO airootfs at /usr/bin/launchpad-daemon and /usr/bin/launchctl.
#
# This must run on Linux with the Rust toolchain. build-iso.sh invokes it
# before mkarchiso so the resulting ISO can boot with LaunchPad as PID 1.
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
launchpad_lib_dir="${base_dir}/TontooLibs/LaunchPad"
launchctl_dir="${base_dir}/TontooProgramms/LaunchCTL"
launchpad_daemon_dir="${base_dir}/TontooServices/LaunchPad"
dest_dir="${base_dir}/BaseOS/archiso/airootfs/usr/bin"

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-launchpad: cargo not found; skipping LaunchPad build" >&2
  exit 0
fi

mkdir -p "${dest_dir}"

# --- Build launchctl CLI (TontooProgramms/LaunchCTL) ---
if [[ -d "${launchctl_dir}" ]]; then
  echo "==> Building launchctl (TontooProgramms/LaunchCTL)..."
  cd "${launchctl_dir}"
  cargo build --release
  cp -f "${launchctl_dir}/target/release/launchctl" "${dest_dir}/launchctl"
  chmod 0755 "${dest_dir}/launchctl"
  echo "==> launchctl -> ${dest_dir}/launchctl"
else
  echo "stage-launchpad: LaunchCTL directory not found at ${launchctl_dir}" >&2
fi

# --- Build launchpad-daemon (TontooServices/LaunchPad) ---
if [[ -d "${launchpad_daemon_dir}" ]]; then
  echo "==> Building launchpad-daemon (TontooServices/LaunchPad)..."
  cd "${launchpad_daemon_dir}"
  cargo build --release
  cp -f "${launchpad_daemon_dir}/target/release/launchpad-daemon" "${dest_dir}/launchpad-daemon"
  chmod 0755 "${dest_dir}/launchpad-daemon"
  echo "==> launchpad-daemon -> ${dest_dir}/launchpad-daemon"
else
  echo "stage-launchpad: LaunchPad daemon directory not found at ${launchpad_daemon_dir}" >&2
fi

# Backwards compat: old workspace TontooLibs/LaunchPad built both binaries
if [[ ! -f "${dest_dir}/launchctl" ]] || [[ ! -f "${dest_dir}/launchpad-daemon" ]]; then
  if [[ -d "${launchpad_lib_dir}" ]] && [[ -f "${launchpad_lib_dir}/Cargo.toml" ]]; then
    if grep -q "launchctl\|launchpad-daemon" "${launchpad_lib_dir}/Cargo.toml" 2>/dev/null; then
      echo "==> Fallback: Building legacy TontooLibs/LaunchPad workspace..."
      cd "${launchpad_lib_dir}"
      cargo build --release || true
      [[ -f "${launchpad_lib_dir}/target/release/launchctl" ]] && cp -f "${launchpad_lib_dir}/target/release/launchctl" "${dest_dir}/launchctl" && chmod 0755 "${dest_dir}/launchctl" || true
      [[ -f "${launchpad_lib_dir}/target/release/launchpad-daemon" ]] && cp -f "${launchpad_lib_dir}/target/release/launchpad-daemon" "${dest_dir}/launchpad-daemon" && chmod 0755 "${dest_dir}/launchpad-daemon" || true
    fi
  fi
fi

echo "==> LaunchPad binaries -> ${dest_dir}"

# Stage LaunchPad language files (remain in TontooLibs/LaunchPad)
lang_dest="${base_dir}/BaseOS/archiso/airootfs/usr/share/launchpad/lang"
mkdir -p "${lang_dest}"
if [[ -d "${launchpad_lib_dir}/lang" ]]; then
  cp -f "${launchpad_lib_dir}/lang/en_us.json" "${lang_dest}/en_us.json"
  cp -f "${launchpad_lib_dir}/lang/de_de.json" "${lang_dest}/de_de.json"
  chmod 0644 "${lang_dest}/en_us.json" "${lang_dest}/de_de.json"
  echo "==> LaunchPad lang -> ${lang_dest}"
fi

#!/usr/bin/env bash
# Build the LaunchPad daemon and launchctl CLI, then place the binaries
# into the live ISO airootfs at /usr/bin/launchpad-daemon and /usr/bin/launchctl.
#
# Sources are the sibling component repos next to this checkout:
#   <checkout>/../TontooServices/LaunchPad -> launchpad-daemon (PID 1)
#   <checkout>/../TontooProgramms/LaunchCTL -> launchctl CLI
#   <checkout>/../TontooLibs/LaunchPad     -> lang files
# (On Windows: C:\Users\arlo1\Documents\TontooServices\LaunchPad, etc.)
# In --github-actions mode build-iso.sh pre-clones the same repos into
# <checkout>/TontooServices, <checkout>/TontooProgramms and
# <checkout>/TontooLibs, so the in-repo paths are used instead.
# There is no legacy fallback: the old TontooLibs/LaunchPad daemon
# workspace is gone.
#
# This must run on Linux with the Rust toolchain. build-iso.sh invokes it
# before mkarchiso so the resulting ISO can boot with LaunchPad as PID 1.
set -euo pipefail

# Accepts --github-actions (forwarded by build-iso.sh). In that mode all
# external sources are pre-cloned to the in-repo paths, so the sibling
# defaults below are replaced with the clone locations.
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
if [[ "${GITHUB_ACTIONS_BUILD}" -eq 1 ]]; then
  launchpad_daemon_dir="${LAUNCHPAD_DAEMON_DIR:-${base_dir}/TontooServices/LaunchPad}"
  launchctl_dir="${LAUNCHCTL_DIR:-${base_dir}/TontooProgramms/LaunchCTL}"
  launchpad_lib_dir="${TONTOO_LIBS_SRC:-${base_dir}/TontooLibs}/LaunchPad"
else
  launchpad_daemon_dir="${LAUNCHPAD_DAEMON_DIR:-${base_dir}/../TontooServices/LaunchPad}"
  launchctl_dir="${LAUNCHCTL_DIR:-${base_dir}/../TontooProgramms/LaunchCTL}"
  launchpad_lib_dir="${TONTOO_LIBS_SRC:-${base_dir}/../TontooLibs}/LaunchPad"
fi
dest_dir="${base_dir}/BaseOS/archiso/airootfs/usr/bin"

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-launchpad: cargo not found; skipping LaunchPad build" >&2
  exit 0
fi

mkdir -p "${dest_dir}"

# --- Build launchctl CLI (sibling TontooProgramms/LaunchCTL) ---
if [[ -d "${launchctl_dir}" ]]; then
  echo "==> Building launchctl (${launchctl_dir})..."
  cd "${launchctl_dir}"
  cargo build --release
  if [[ -f "${launchctl_dir}/target/release/launchctl" ]]; then
    cp -f "${launchctl_dir}/target/release/launchctl" "${dest_dir}/launchctl"
    chmod 0755 "${dest_dir}/launchctl"
    echo "==> launchctl -> ${dest_dir}/launchctl"
  else
    echo "WARNING: stage-launchpad: launchctl was not built, skipping." >&2
  fi
else
  echo "stage-launchpad: LaunchCTL directory not found at ${launchctl_dir}" >&2
fi

# --- Build launchpad-daemon (sibling TontooServices/LaunchPad) ---
if [[ -d "${launchpad_daemon_dir}" ]]; then
  echo "==> Building launchpad-daemon (${launchpad_daemon_dir})..."
  cd "${launchpad_daemon_dir}"
  cargo build --release
  if [[ -f "${launchpad_daemon_dir}/target/release/launchpad-daemon" ]]; then
    cp -f "${launchpad_daemon_dir}/target/release/launchpad-daemon" "${dest_dir}/launchpad-daemon"
    chmod 0755 "${dest_dir}/launchpad-daemon"
    echo "==> launchpad-daemon -> ${dest_dir}/launchpad-daemon"
  else
    echo "WARNING: stage-launchpad: launchpad-daemon was not built, skipping." >&2
  fi
else
  echo "stage-launchpad: LaunchPad daemon directory not found at ${launchpad_daemon_dir}" >&2
fi

if [[ ! -f "${dest_dir}/launchctl" ]] || [[ ! -f "${dest_dir}/launchpad-daemon" ]]; then
  echo "WARNING: stage-launchpad: one or more binaries missing (launchctl/launchpad-daemon)." >&2
fi

echo "==> LaunchPad binaries -> ${dest_dir}"

# Stage LaunchPad language files (sibling TontooLibs/LaunchPad)
lang_dest="${base_dir}/BaseOS/archiso/airootfs/usr/share/launchpad/lang"
mkdir -p "${lang_dest}"
if [[ -d "${launchpad_lib_dir}/lang" ]]; then
  cp -f "${launchpad_lib_dir}/lang/en_us.json" "${lang_dest}/en_us.json"
  cp -f "${launchpad_lib_dir}/lang/de_de.json" "${lang_dest}/de_de.json"
  chmod 0644 "${lang_dest}/en_us.json" "${lang_dest}/de_de.json"
  echo "==> LaunchPad lang -> ${lang_dest}"
fi

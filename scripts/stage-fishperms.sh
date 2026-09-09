#!/usr/bin/env bash
# Build the FishPerms permission daemon and fishpermctl CLI, then place the
# binaries into the live ISO airootfs at /usr/bin/fishperms-daemon and
# /usr/bin/fishpermctl, plus the LaunchPad service definition.
#
# This must run on Linux with the Rust toolchain. build-iso.sh invokes it
# before mkarchiso so LaunchPad (PID 1) starts FishPerms on boot.
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
fishperms_dir="${base_dir}/TontooServices/FishPerms"
dest_dir="${base_dir}/BaseOS/archiso/airootfs/usr/bin"
service_dest_dir="${base_dir}/BaseOS/archiso/airootfs/System/services"

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-fishperms: cargo not found; skipping FishPerms build" >&2
  exit 0
fi

if [[ ! -d "${fishperms_dir}" ]]; then
  echo "stage-fishperms: FishPerms directory not found at ${fishperms_dir}" >&2
  exit 0
fi

echo "==> Building FishPerms (daemon + ctl)..."
cd "${fishperms_dir}"
cargo build --release --workspace

mkdir -p "${dest_dir}"
for bin in fishperms-daemon fishpermctl fishperms-prompt fishbox; do
  if [[ -f "${fishperms_dir}/target/release/${bin}" ]]; then
    cp -f "${fishperms_dir}/target/release/${bin}" "${dest_dir}/${bin}"
    chmod 0755 "${dest_dir}/${bin}"
  else
    echo "WARNING: stage-fishperms: ${bin} was not built, skipping." >&2
  fi
done
echo "==> FishPerms binaries -> ${dest_dir}"

# Stage the LaunchPad service definition
if [[ -f "${fishperms_dir}/launchpad/FishPerms.service" ]]; then
  mkdir -p "${service_dest_dir}"
  cp -f "${fishperms_dir}/launchpad/FishPerms.service" "${service_dest_dir}/FishPerms.service"
  chmod 0644 "${service_dest_dir}/FishPerms.service"
  echo "==> FishPerms.service -> ${service_dest_dir}"
else
  echo "stage-fishperms: launchpad/FishPerms.service not found; service not staged" >&2
fi

# Policy database directory (empty, filled by the daemon at runtime)
policy_dir="${base_dir}/BaseOS/archiso/airootfs/Library/Preferences/FishPerms"
mkdir -p "${policy_dir}"
chmod 0755 "${policy_dir}"
echo "==> FishPerms policy dir -> ${policy_dir}"

# Stage the default protection policy
if [[ -f "${fishperms_dir}/policy/protected.conf" ]]; then
  cp -f "${fishperms_dir}/policy/protected.conf" "${policy_dir}/protected.conf"
  chmod 0644 "${policy_dir}/protected.conf"
  echo "==> FishPerms policy -> ${policy_dir}/protected.conf"
else
  echo "stage-fishperms: policy/protected.conf not found; default policy not staged" >&2
fi

# Stage the trusted executables list
if [[ -f "${fishperms_dir}/policy/trusted.conf" ]]; then
  cp -f "${fishperms_dir}/policy/trusted.conf" "${policy_dir}/trusted.conf"
  chmod 0644 "${policy_dir}/trusted.conf"
  echo "==> FishPerms trust list -> ${policy_dir}/trusted.conf"
else
  echo "stage-fishperms: policy/trusted.conf not found; trust list not staged" >&2
fi

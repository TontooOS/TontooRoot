#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This build helper must run on Linux with archiso installed." >&2
  exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso was not found. Install the archiso package first." >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
profile_dir="${base_dir}/BaseOS/archiso"
output_dir="${base_dir}/BaseOS/out"
work_dir="${ARCHISO_WORKDIR:-/tmp/baseos-archiso-work}"

# Fix CRLF and UTF-8 BOM on ALL shell scripts (NTFS/WSL compat)
echo "==> Fixing line endings on all scripts..."
find "${base_dir}/BaseOS/scripts" -name '*.sh' -exec sed -i -e 's/\r$//' -e '1s/^\xEF\xBB\xBF//' {} + 2>/dev/null || true
find "${base_dir}/ai_temp_filees" -name '*.sh' -exec sed -i -e 's/\r$//' -e '1s/^\xEF\xBB\xBF//' {} + 2>/dev/null || true
find "${profile_dir}/airootfs" -name '*.sh' -exec sed -i -e 's/\r$//' -e '1s/^\xEF\xBB\xBF//' {} + 2>/dev/null || true

# Ensure airootfs helper scripts are executable (NTFS loses +x)
echo "==> Fixing permissions on airootfs scripts..."
chmod 0755 "${profile_dir}/airootfs/usr/local/bin/"* 2>/dev/null || true
chmod 0755 "${profile_dir}/airootfs/usr/local/bin/baseos-setup-session" 2>/dev/null || true
chmod 0755 "${profile_dir}/airootfs/usr/local/lib/archiso/enable-live-desktop.sh" 2>/dev/null || true

sudo_cmd=()
if [[ "${EUID}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Run as root or install sudo." >&2
    exit 1
  fi
  sudo_cmd=(sudo)
fi

mkdir -p "${output_dir}"

# Clean stale work directory from previous builds to avoid file conflicts
if [[ -d "${work_dir}" ]]; then
  echo "Cleaning stale work directory..."
  "${sudo_cmd[@]}" rm -rf "${work_dir}"
fi

bash "${base_dir}/BaseOS/scripts/stage-fonts.sh"
bash "${base_dir}/BaseOS/scripts/stage-launchpad.sh"
bash "${base_dir}/BaseOS/scripts/stage-fishrunner.sh"
bash "${base_dir}/BaseOS/scripts/stage-fishperms.sh"
bash "${base_dir}/BaseOS/scripts/stage-compositor.sh"
bash "${base_dir}/BaseOS/scripts/stage-menubar.sh"
bash "${base_dir}/BaseOS/scripts/stage-cursors.sh"
bash "${base_dir}/BaseOS/scripts/stage-wallpapers.sh"
bash "${base_dir}/BaseOS/scripts/stage-frameworks.sh"
bash "${base_dir}/BaseOS/scripts/stage-sshd.sh"

"${sudo_cmd[@]}" mkarchiso -v -w "${work_dir}" -o "${output_dir}" "${profile_dir}"

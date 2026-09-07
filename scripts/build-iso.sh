#!/usr/bin/env bash
set -euo pipefail

# Usage: build-iso.sh [--github-actions]
#
# Without flags, all component sources are taken from local directories
# (compositor/, TontooServices/, TontooProgramms/, TontooLibs/, ... next to
# this repo). With --github-actions, those sources are cloned from
# github.com/${GITHUB_ORG} first and then used from the same local paths.
# The flag is forwarded to every stage-*.sh helper.
GITHUB_ACTIONS_BUILD=0
for arg in "$@"; do
  case "${arg}" in
    --github-actions)
      GITHUB_ACTIONS_BUILD=1
      ;;
    -h|--help)
      echo "Usage: build-iso.sh [--github-actions]"
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

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

GITHUB_ORG="${GITHUB_ORG:-TontooOS}"

clone_github_repo() { # clone_github_repo <repo> <dest>
  local repo="$1"
  local dest="$2"
  if [[ -e "${dest}" ]]; then
    echo "  exists, skipping: ${dest}"
    return 0
  fi
  echo "  cloning ${GITHUB_ORG}/${repo} -> ${dest}"
  git clone --depth 1 "https://github.com/${GITHUB_ORG}/${repo}.git" "${dest}"
}

if [[ "${GITHUB_ACTIONS_BUILD}" -eq 1 ]]; then
  echo "==> GitHub Actions mode: fetching external sources..."
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required for --github-actions." >&2
    exit 1
  fi
  mkdir -p "${base_dir}/TontooProgramms" "${base_dir}/TontooServices" "${base_dir}/TontooLibs"
  clone_github_repo Compositor "${base_dir}/compositor"
  clone_github_repo FishPerms "${base_dir}/TontooServices/FishPerms"
  clone_github_repo LaunchPad "${base_dir}/TontooServices/LaunchPad"
  clone_github_repo LaunchCTL "${base_dir}/TontooProgramms/LaunchCTL"
  clone_github_repo FishRunner "${base_dir}/TontooProgramms/FishRunner"
  clone_github_repo MenuBar "${base_dir}/TontooProgramms/Menubar"
  clone_github_repo TBuild "${base_dir}/TontooProgramms/TBuild"
  clone_github_repo LaunchPadLib "${base_dir}/TontooLibs/LaunchPad"
  for framework in Accessibility CoreLocation CoreIcon Foundation NetworkKit UIKitDynamics UIKit WebKit TontooUI MapsKit WeatherKit; do
    clone_github_repo "${framework}" "${base_dir}/TontooLibs/${framework}"
  done
  # Point helpers with configurable source locations at the clones.
  export TONTOO_LIBS_SRC="${TONTOO_LIBS_SRC:-${base_dir}/TontooLibs}"
  export FISHRUNNER_DIR="${FISHRUNNER_DIR:-${base_dir}/TontooProgramms/FishRunner}"
fi

# Fix CRLF and UTF-8 BOM on ALL shell scripts (NTFS/WSL compat)
echo "==> Fixing line endings on all scripts..."
find "${base_dir}/BaseOS/scripts" -name '*.sh' -exec sed -i -e 's/\r$//' -e '1s/^\xEF\xBB\xBF//' {} + 2>/dev/null || true
find "${base_dir}/BaseOS/vendor" -name '*.sh' -exec sed -i -e 's/\r$//' -e '1s/^\xEF\xBB\xBF//' {} + 2>/dev/null || true
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

stage_flags=()
if [[ "${GITHUB_ACTIONS_BUILD}" -eq 1 ]]; then
  stage_flags=(--github-actions)
fi

bash "${base_dir}/BaseOS/scripts/stage-fonts.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-launchpad.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-fishrunner.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-fishperms.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-compositor.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-menubar.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-cursors.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-wallpapers.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-frameworks.sh" "${stage_flags[@]}"
bash "${base_dir}/BaseOS/scripts/stage-sshd.sh" "${stage_flags[@]}"

"${sudo_cmd[@]}" mkarchiso -v -w "${work_dir}" -o "${output_dir}" "${profile_dir}"

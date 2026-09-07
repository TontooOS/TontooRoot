#!/usr/bin/env bash
# Build the TontooOS shell UI (topbar + dock) and place the binary
# into the live ISO airootfs at /usr/bin/tontoo-shell-ui.
set -euo pipefail

# Accepts --github-actions (forwarded by build-iso.sh). No path changes:
# shell_ui sources are expected next to this repo in both modes.
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
shell_dir="${base_dir}/shell_ui"
dest_dir="${base_dir}/BaseOS/archiso/airootfs/usr/bin"
dest="${dest_dir}/tontoo-shell-ui"

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-shell-ui: cargo not found; skipping shell UI build" >&2
  exit 0
fi

if [[ ! -d "${shell_dir}" ]]; then
  echo "stage-shell-ui: shell_ui directory not found at ${shell_dir}" >&2
  exit 1
fi

# Install build dependencies if on Arch Linux
if [[ "$(uname -s)" == "Linux" ]] && command -v pacman >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
  pacman -S --needed --noconfirm \
    wayland libwayland libxkbcommon \
    >/dev/null 2>&1 || echo "stage-shell-ui: could not install build deps (continuing)" >&2
fi

echo "==> Building tontoo-shell-ui..."
cd "${shell_dir}"
cargo build --release

mkdir -p "${dest_dir}"
cp -f "${shell_dir}/target/release/tontoo-shell-ui" "${dest}"
chmod 0755 "${dest}"
echo "==> Shell UI binary -> ${dest}"

#!/usr/bin/env bash
# Build the TontooOS compositor with the udev/DRM backend and place the binary
# into the live ISO airootfs at /usr/bin/tontoo-compositor.
#
# This must run on Linux with the Rust toolchain and the required system
# libraries installed (see build deps below). build-iso.sh invokes it before
# mkarchiso so the resulting ISO can boot straight into the Wayland session.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
compositor_dir="${base_dir}/compositor"
dest_dir="${base_dir}/BaseOS/archiso/airootfs/usr/bin"
dest="${dest_dir}/tontoo-compositor"

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-compositor: cargo not found; skipping compositor build" >&2
  exit 0
fi

# Best-effort: install build-time system dependencies (Arch Linux, as root).
if [[ "$(uname -s)" == "Linux" ]] && command -v pacman >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
  pacman -S --needed --noconfirm \
    rust libglvnd mesa libinput libxkbcommon wayland libdrm seatd \
    >/dev/null 2>&1 || echo "stage-compositor: could not install build deps (continuing)" >&2
fi

echo "==> Building tontoo-compositor (udev backend)..."
cd "${compositor_dir}"
cargo build --release --no-default-features --features udev

mkdir -p "${dest_dir}"
cp -f "${compositor_dir}/target/release/tontoo-compositor" "${dest}"
chmod 0755 "${dest}"
echo "==> Compositor binary -> ${dest}"

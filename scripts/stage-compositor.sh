#!/usr/bin/env bash
# Build the TontooOS compositor (Wayfire 0.12, wlroots 0.20) and install it
# into the live ISO airootfs via `DESTDIR=airootfs ninja install`: binary
# /usr/bin/wayfire + compat symlink /usr/bin/tontoo-compositor, bundled
# shared libs (libwlroots-0.20, libwf-config, libwf-utils, libyyjson),
# plugins (/usr/lib/wayfire) and metadata. Also installs the TontooOS
# wayfire.ini to /etc/skel/.config/wayfire.ini and
# /usr/share/wayfire/wayfire.ini.tontoo.
#
# This replaces the previous smithay Rust compositor (archived at
# ../compositor_backup_*). Wayfire is built via meson/ninja with bundled
# wlroots (use_system_wlroots=disabled) so the ISO is reproducible without
# needing a system wlroots 0.20.
set -euo pipefail

GITHUB_ACTIONS_BUILD=0
for arg in "$@"; do
  case "${arg}" in
    --github-actions) GITHUB_ACTIONS_BUILD=1 ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
compositor_dir="${base_dir}/compositor"
profile_dir="${base_dir}/BaseOS/archiso"
dest_dir="${profile_dir}/airootfs/usr/bin"
build_dir="/tmp/tontoo-wayfire-build"

if ! command -v meson >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
  echo "stage-compositor: meson/ninja not found; attempting to install..." >&2
  if command -v pacman >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
    pacman -Sy --needed --noconfirm meson ninja gcc pkgconf wayland wayland-protocols libdrm mesa libinput pixman cairo pango glm libxkbcommon libseat libxcb libjpeg-turbo libpng wlroots 2>/dev/null || true
  fi
  if ! command -v meson >/dev/null 2>&1; then
    echo "stage-compositor: meson still not found; skipping compositor build" >&2
    exit 0
  fi
fi

# Best-effort: install build-time system dependencies (Arch Linux, as root).
if [[ "$(uname -s)" == "Linux" ]] && command -v pacman >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
  pacman -S --needed --noconfirm \
    gcc pkgconf wayland wayland-protocols libdrm mesa libinput pixman cairo pango glm libxkbcommon libseat libxcb libjpeg-turbo libpng vulkan-headers wayland-protocols xorg-xwayland libliftoff 2>/dev/null \
    || echo "stage-compositor: could not install all build deps (continuing)" >&2
fi

# Ensure subprojects are at correct commits (fixes manually-cloned subprojects without --recursive)
if [[ -f "${compositor_dir}/.gitmodules" ]]; then
  echo "==> Ensuring Wayfire subprojects..."
  # Map known Wayfire subproject commits (0.12, wlroots 0.20.2)
  declare -A commits=(
    ["wlroots"]="d783533489e1f75d6886c2ab5c5960090ef268f8"
    ["wlroots-vkfx"]="4c89d4b687826641b37e65441ad1cdd1eca40551"
    ["wf-config"]="add9ba7a47492d4f86482b0a308d9054a825637e"
    ["wf-json"]="70039e13cdeaebd8ec498ed30bf5ab91c2e313ec"
    ["wf-touch"]="d7ae5e7fa4de9536e2de2af74f168f981eb8a77a"
    ["wf-utils"]="329c3ff01724d82947f61c45332f75d3534e8454"
  )
  for proj in wlroots wlroots-vkfx wf-config wf-json wf-touch wf-utils; do
    if [[ -d "${compositor_dir}/subprojects/${proj}/.git" ]]; then
      (cd "${compositor_dir}/subprojects/${proj}" && git fetch --depth 50 2>/dev/null || true; git checkout "${commits[$proj]}" 2>/dev/null || true)
    elif [[ ! -d "${compositor_dir}/subprojects/${proj}" ]] || [[ -z "$(ls -A "${compositor_dir}/subprojects/${proj}" 2>/dev/null)" ]]; then
      # Sparse checkout fallback - clone manually
      rm -rf "${compositor_dir}/subprojects/${proj}"
      case "$proj" in
        wlroots) git clone https://gitlab.freedesktop.org/wlroots/wlroots.git "${compositor_dir}/subprojects/${proj}" 2>/dev/null || true ;;
        wlroots-vkfx) git clone https://gitlab.freedesktop.org/ammen99/wlroots "${compositor_dir}/subprojects/${proj}" 2>/dev/null || true ;;
        wf-config) git clone https://github.com/WayfireWM/wf-config "${compositor_dir}/subprojects/${proj}" 2>/dev/null || true ;;
        wf-json) git clone https://github.com/WayfireWM/wf-json "${compositor_dir}/subprojects/${proj}" 2>/dev/null || true ;;
        wf-touch) git clone https://github.com/WayfireWM/wf-touch "${compositor_dir}/subprojects/${proj}" 2>/dev/null || true ;;
        wf-utils) git clone https://github.com/WayfireWM/wf-utils "${compositor_dir}/subprojects/${proj}" 2>/dev/null || true ;;
      esac
      (cd "${compositor_dir}/subprojects/${proj}" && git checkout "${commits[$proj]}" 2>/dev/null || true)
    fi
  done
fi

echo "==> Building wayfire (TontooOS compositor, Wayfire 0.12)..."
rm -rf "${build_dir}"
mkdir -p "${build_dir}"
meson setup "${compositor_dir}" "${build_dir}" \
  --prefix=/usr \
  --libdir=lib \
  --buildtype=release \
  -Duse_system_wlroots=disabled \
  -Duse_system_wfconfig=disabled \
  -Dxwayland=enabled \
  -Denable_gles32=true \
  -Dvulkan_effects=false

ninja -C "${build_dir}" -j"$(nproc 2>/dev/null || echo 4)"

airootfs_dir="${profile_dir}/airootfs"
mkdir -p "${dest_dir}" "${airootfs_dir}"

# Full install into airootfs (binary + bundled libs + plugins + metadata).
# A binary-only copy is NOT enough: wayfire links against the bundled
# wlroots 0.20 / wf-config / wf-utils / wf-json builds, so without
# `ninja install` the live system misses libwlroots-0.20.so,
# libwf-config.so.1, libwf-utils.so.0, libyyjson.so.0 and all
# /usr/lib/wayfire plugins (live symptom: start-compositor.sh loops,
# `ldd /usr/bin/wayfire` shows "not found", no WAYLAND_DISPLAY).
echo "==> Installing wayfire + bundled libs/plugins into airootfs..."
if ! DESTDIR="${airootfs_dir}" ninja -C "${build_dir}" install; then
  echo "WARNING: stage-compositor: 'ninja install' failed, falling back to binary-only copy." >&2
  if [[ -f "${build_dir}/src/wayfire" ]]; then
    cp -f "${build_dir}/src/wayfire" "${dest_dir}/wayfire"
    chmod 0755 "${dest_dir}/wayfire"
  else
    echo "WARNING: stage-compositor: wayfire was not built, skipping." >&2
  fi
fi

if [[ -f "${dest_dir}/wayfire" ]]; then
  chmod 0755 "${dest_dir}/wayfire"
  # Compat symlink: old start-compositor.sh and LaunchPad services referenced /usr/bin/tontoo-compositor
  ln -sf wayfire "${dest_dir}/tontoo-compositor"
  echo "==> Compositor binary -> ${dest_dir}/wayfire (symlink tontoo-compositor)"
  # Shared libs must stay executable after staging (squashfs keeps staged modes).
  find "${airootfs_dir}/usr/lib" \( -name 'libwlroots-0.20.so*' -o -name 'libwf-*.so*' -o -name 'libyyjson.so*' \) -exec chmod 0755 {} + 2>/dev/null || true
  find "${airootfs_dir}/usr/lib/wayfire" -name '*.so' -exec chmod 0755 {} + 2>/dev/null || true
else
  echo "WARNING: stage-compositor: wayfire was not built, skipping." >&2
fi

# Install plugins and data files to airootfs (needed for runtime)
if [[ -d "${build_dir}/metadata" ]]; then
  mkdir -p "${profile_dir}/airootfs/usr/share/wayfire/metadata"
  cp -a "${compositor_dir}/metadata/"*.xml "${profile_dir}/airootfs/usr/share/wayfire/metadata/" 2>/dev/null || true
fi

# Install TontooOS wayfire.ini to skel and to /usr/share/wayfire
echo "==> Installing TontooOS wayfire.ini..."
mkdir -p "${profile_dir}/airootfs/etc/skel/.config"
mkdir -p "${profile_dir}/airootfs/usr/share/wayfire"
if [[ -f "${compositor_dir}/wayfire.ini" ]]; then
  cp -f "${compositor_dir}/wayfire.ini" "${profile_dir}/airootfs/etc/skel/.config/wayfire.ini"
  cp -f "${compositor_dir}/wayfire.ini" "${profile_dir}/airootfs/usr/share/wayfire/wayfire.ini.tontoo"
  echo "==> wayfire.ini -> /etc/skel/.config/wayfire.ini + /usr/share/wayfire/wayfire.ini.tontoo"
fi
if [[ -f "${compositor_dir}/wayfire.ini.upstream" ]]; then
  cp -f "${compositor_dir}/wayfire.ini.upstream" "${profile_dir}/airootfs/usr/share/wayfire/wayfire.ini.upstream" 2>/dev/null || true
fi

# Also install wayfire.desktop session file
if [[ -f "${compositor_dir}/wayfire.desktop" ]]; then
  mkdir -p "${profile_dir}/airootfs/usr/share/wayland-sessions"
  cp -f "${compositor_dir}/wayfire.desktop" "${profile_dir}/airootfs/usr/share/wayland-sessions/wayfire.desktop" 2>/dev/null || true
  # TontooOS session entry (points to wayfire with TontooOS config)
  cat > "${profile_dir}/airootfs/usr/share/wayland-sessions/tontoo.desktop" <<'DESKTOP'
[Desktop Entry]
Name=TontooOS (Wayfire)
Comment=TontooOS Desktop - Wayfire compositor
Exec=wayfire
Type=Application
DesktopNames=TontooOS;Wayfire;wlroots
DESKTOP
fi

# Cleanup build dir (keep for debugging if needed - comment out to preserve)
# rm -rf "${build_dir}"

#!/usr/bin/env bash
set -euo pipefail

# Builds the TontooOS Qt Wayland client-side decoration plugin and installs it
# into the ISO image.
#
# Why this exists: Qt does not draw client-side decoration titlebars through
# QStyle. On Wayland it loads a "wayland-decoration-client" plugin instead
# (stock Qt ships one called "bradient" that puts plain window buttons on the
# right). The tontoo plugin draws macOS traffic lights on the left, matching
# the compositor's shell::window_controls geometry.
#
# Both a Qt5 and a Qt6 build are produced when the matching -dev package is
# present; each one lands next to the Qt version it was built for, because
# Qt's plugin loader only scans that version's plugin directory.
#
# Accepts --github-actions (forwarded by build-iso.sh), unused otherwise.

for arg in "$@"; do
  case "${arg}" in
    --github-actions) ;;
    *) echo "Unknown argument: ${arg}" >&2; exit 1 ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
src_dir="${base_dir}/qt-decoration"
profile_dir="${base_dir}/BaseOS/archiso"
dest_root="${profile_dir}/airootfs/usr"

if [[ ! -f "${src_dir}/src/tontoo_decoration.cpp" ]]; then
  echo "tontoo-decoration sources not found at ${src_dir}, skipping." >&2
  exit 0
fi

# The plugin is built inside the image root so the resulting .so is already in
# place for mkarchiso. Nothing is installed into the build host.
build_dir="$(mktemp -d)"
trap 'rm -rf "${build_dir}"' EXIT

built=0

build_for() { # build_for <qt major>
  local major="$1"

  # Arch installs Qt5's moc as moc-qt5 and Qt6's as plain moc, so try the
  # versioned name first and fall back to the unversioned one.
  local moc=""
  local candidate
  for candidate in "moc-qt${major}" moc; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      moc="${candidate}"
      break
    fi
  done

  if [[ -z "${moc}" ]]; then
    echo "  Qt${major}: moc not found, skipping."
    return 0
  fi

  local qt_incdir="/usr/include/qt${major}"
  if [[ "${major}" == "5" ]]; then
    qt_incdir="/usr/include/qt"
  fi
  if [[ ! -d "${qt_incdir}" ]]; then
    echo "  Qt${major}: headers not found at ${qt_incdir}, skipping."
    return 0
  fi

  local work="${build_dir}/qt${major}"
  mkdir -p "${work}"
  cp "${src_dir}/src/tontoo_decoration.cpp" "${work}/"
  cp "${src_dir}/src/tontoo.json" "${work}/"

  # moc cannot expand QWaylandDecorationFactoryInterface_iid, but the source
  # already spells the IID out as a literal, so a plain run is enough.
  if ! "${moc}" "${work}/tontoo_decoration.cpp" -o "${work}/tontoo.moc"; then
    echo "  Qt${major}: moc failed, skipping." >&2
    return 0
  fi

  # Collect every include dir the private decoration headers pull in.
  #
  # Qt lays its headers out as <incdir>/<Module> and then, for the real
  # headers, <incdir>/<Module>/<version>/<Module>. The private/ subdirs and
  # the qpa/ headers (qpa/qwindowsysteminterface.h) only exist in that second,
  # versioned level, so both levels are needed.
  local includes=()
  local d v
  includes+=("-I${qt_incdir}")
  for d in "${qt_incdir}"/*/; do
    [[ -d "${d}" ]] || continue
    includes+=("-I${d}")
    for v in "${d}"*/; do
      [[ -d "${v}" ]] || continue
      includes+=("-I${v}")
      # <incdir>/<Module>/<version>/<Module> holds qpa/, <...>/private holds
      # the private headers.
      if [[ -d "${v}$(basename "${d%/}")" ]]; then
        includes+=("-I${v}$(basename "${d%/}")")
      fi
      [[ -d "${v}$(basename "${d%/}")/private" ]] && \
        includes+=("-I${v}$(basename "${d%/}")/private")
    done
  done

  # Link Qt explicitly, the same way Qt's own decoration plugins do. Without it
  # the Qt symbols stay undefined and would be resolved from whatever process
  # loads the plugin, so a Qt5 build could bind against a Qt6 host and crash
  # instead of failing to load.
  local libs=("-lQt${major}Core" "-lQt${major}Gui" "-lQt${major}WaylandClient")

  if ! g++ -std=c++17 -fPIC -shared -O2 \
      -o "${work}/libtontoo.so" "${work}/tontoo_decoration.cpp" \
      "${includes[@]}" "${libs[@]}" 2>"${work}/build.log"; then
    echo "  Qt${major}: compile failed:" >&2
    sed 's/^/    /' "${work}/build.log" >&2
    return 0
  fi

  local plugin_dir="${dest_root}/lib/qt${major}/plugins/wayland-decoration-client"
  mkdir -p "${plugin_dir}"
  install -Dm0755 "${work}/libtontoo.so" "${plugin_dir}/libtontoo.so"
  echo "  Qt${major}: installed to ${plugin_dir}"
  built=$((built + 1))
}

echo "==> Building TontooOS Qt Wayland decoration plugin..."

build_for 5
build_for 6

if [[ "${built}" -eq 0 ]]; then
  echo "WARNING: no Qt version built (need qt5-wayland/qt6-wayland + base-devel in airootfs)." >&2
  exit 0
fi

echo "==> tontoo decoration staged (${built} Qt version(s))"
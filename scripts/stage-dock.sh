#!/usr/bin/env bash
# Build the TontooOS Dock system app with TBuild and stage it into the
# live ISO airootfs as an extracted bundle at /System/Applications/Dock.app.
#
# The compositor renders no dock itself; the bottom dock is this
# external app, started at boot via the `dock` LaunchPad service
# (System/services/dock.service -> start-dock.sh -> tapp).
#
# build-iso.sh invokes this before mkarchiso.
set -euo pipefail

# Accepts --github-actions (forwarded by build-iso.sh). In that mode the
# Dock and TBuild sources are pre-cloned to the standard local paths
# checked below, so this script needs no path changes.
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
apps_dir="${profile_dir}/airootfs/System/Applications"
dest_dir="${apps_dir}/Dock.app"
lang_dest="${profile_dir}/airootfs/usr/share/tontoo/dock/lang"

# --- Locate the Dock project ---
dock_dir=""
for candidate in \
  "${base_dir}/TontooProgramms/Dock" \
  "${base_dir}/../TontooProgramms/Dock" \
  "${DOCK_DIR:-/nonexistent}"; do
  if [[ -f "${candidate}/tontoo.proj" ]]; then
    dock_dir="${candidate}"
    break
  fi
done

if [[ -z "${dock_dir}" ]]; then
  echo "stage-dock: Dock project (tontoo.proj) not found; skipping dock staging" >&2
  exit 0
fi

# --- Locate or build tbuild ---
tbuild_bin=""
for candidate in \
  "${base_dir}/TontooProgramms/TBuild/target/release/tbuild" \
  "${base_dir}/../TontooProgramms/TBuild/target/release/tbuild" \
  "${TBUILD_BIN:-/nonexistent}"; do
  if [[ -x "${candidate}" ]]; then
    tbuild_bin="${candidate}"
    break
  fi
done

if [[ -z "${tbuild_bin}" ]]; then
  tbuild_src=""
  for candidate in \
    "${base_dir}/TontooProgramms/TBuild" \
    "${base_dir}/../TontooProgramms/TBuild"; do
    if [[ -f "${candidate}/Cargo.toml" ]]; then
      tbuild_src="${candidate}"
      break
    fi
  done
  if [[ -z "${tbuild_src}" ]]; then
    echo "stage-dock: TBuild not found; skipping dock staging" >&2
    exit 0
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    echo "stage-dock: cargo not found; skipping dock staging" >&2
    exit 0
  fi
  echo "==> Building tbuild..."
  (cd "${tbuild_src}" && cargo build --release)
  tbuild_bin="${tbuild_src}/target/release/tbuild"
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-dock: cargo not found; skipping dock staging" >&2
  exit 0
fi

# --- Build the .app bundle with TBuild ---
out_dir="$(mktemp -d)"
trap 'rm -rf "${out_dir}"' EXIT
echo "==> Building Dock.app with TBuild (${dock_dir})..."
"${tbuild_bin}" app "${dock_dir}" --out "${out_dir}"

app_zip="${out_dir}/Dock.app"
if [[ ! -f "${app_zip}" ]]; then
  echo "WARNING: stage-dock: TBuild did not produce ${app_zip}, skipping dock staging." >&2
  exit 0
fi

# --- Extract the bundle into /System/Applications/Dock.app ---
# The .app is a ZIP archive with a top-level `Dock.app/` directory.
rm -rf "${dest_dir}"
mkdir -p "${apps_dir}"
python3 - "${app_zip}" "${apps_dir}" <<'EOF'
import sys
import zipfile

zip_path, dest_root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as z:
    for info in z.infolist():
        name = info.filename
        # Strip the top-level `Dock.app/` prefix
        parts = name.split('/', 1)
        if len(parts) != 2 or not parts[1]:
            continue
        target = dest_root + '/Dock.app/' + parts[1]
        if info.is_dir():
            __import__('os').makedirs(target, exist_ok=True)
        else:
            __import__('os').makedirs(__import__('os').path.dirname(target), exist_ok=True)
            with open(target, 'wb') as f:
                f.write(z.read(name))
EOF

# The bundle binary must stay executable (squashfs preserves staging perms)
if [[ -f "${dest_dir}/App/dock" ]]; then
  chmod 0755 "${dest_dir}/App/dock"
fi
chmod 0755 "${dest_dir}" 2>/dev/null || true
echo "==> Dock.app bundle -> ${dest_dir}"

# --- Stage Dock language files (the app looks them up under
# --- /usr/share/tontoo/dock/lang/<locale>.json) ---
mkdir -p "${lang_dest}"
if [[ -d "${dock_dir}/lang" ]]; then
  cp -f "${dock_dir}/lang/en_us.json" "${lang_dest}/en_us.json"
  cp -f "${dock_dir}/lang/de_de.json" "${lang_dest}/de_de.json"
  chmod 0644 "${lang_dest}/en_us.json" "${lang_dest}/de_de.json"
  echo "==> Dock lang -> ${lang_dest}"
fi

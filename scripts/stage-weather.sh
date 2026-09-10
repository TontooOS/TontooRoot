#!/usr/bin/env bash
# Build the TontooOS Weather app with TBuild and stage it into the
# live ISO airootfs as an extracted bundle at /Applications/Weather.app.
#
# Unlike the system apps under /System/Applications (Menubar, SystemOverview,
# AboutThisApp), Weather is a user-facing app and lives at the top-level
# /Applications path. Launched on demand via tapp, no service, no symlink.
#
# build-iso.sh invokes this before mkarchiso.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
profile_dir="${base_dir}/BaseOS/archiso"
apps_dir="${profile_dir}/airootfs/Applications"
dest_dir="${apps_dir}/Weather.app"
lang_dest="${profile_dir}/airootfs/usr/share/weather/lang"

# --- Locate the Weather project ---
weather_dir=""
for candidate in \
  "${base_dir}/../TontooMicroApps/Weather" \
  "${WEATHER_DIR:-/nonexistent}"; do
  if [[ -f "${candidate}/tontoo.proj" ]]; then
    weather_dir="${candidate}"
    break
  fi
done

if [[ -z "${weather_dir}" ]]; then
  echo "stage-weather: Weather project (tontoo.proj) not found; skipping weather staging" >&2
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
    echo "stage-weather: TBuild not found; skipping weather staging" >&2
    exit 0
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    echo "stage-weather: cargo not found; skipping weather staging" >&2
    exit 0
  fi
  echo "==> Building tbuild..."
  (cd "${tbuild_src}" && cargo build --release)
  tbuild_bin="${tbuild_src}/target/release/tbuild"
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-weather: cargo not found; skipping weather staging" >&2
  exit 0
fi

# --- Build the .app bundle with TBuild ---
out_dir="$(mktemp -d)"
trap 'rm -rf "${out_dir}"' EXIT
echo "==> Building Weather.app with TBuild (${weather_dir})..."
"${tbuild_bin}" app "${weather_dir}" --out "${out_dir}"

app_zip="${out_dir}/Weather.app"
if [[ ! -f "${app_zip}" ]]; then
  echo "WARNING: stage-weather: TBuild did not produce ${app_zip}, skipping weather staging." >&2
  exit 0
fi

# --- Extract the bundle into /Applications/Weather.app ---
# The .app is a ZIP archive with a top-level `Weather.app/` directory.
rm -rf "${dest_dir}"
mkdir -p "${apps_dir}"
python3 - "${app_zip}" "${apps_dir}" <<'EOF'
import sys
import zipfile

zip_path, dest_root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as z:
    for info in z.infolist():
        name = info.filename
        # Strip the top-level `Weather.app/` prefix
        parts = name.split('/', 1)
        if len(parts) != 2 or not parts[1]:
            continue
        target = dest_root + '/Weather.app/' + parts[1]
        if info.is_dir():
            __import__('os').makedirs(target, exist_ok=True)
        else:
            __import__('os').makedirs(__import__('os').path.dirname(target), exist_ok=True)
            with open(target, 'wb') as f:
                f.write(z.read(name))
EOF

# The bundle binary must stay executable (squashfs preserves staging perms)
if [[ -f "${dest_dir}/App/weather" ]]; then
  chmod 0755 "${dest_dir}/App/weather"
fi
chmod 0755 "${dest_dir}" 2>/dev/null || true
echo "==> Weather.app bundle -> ${dest_dir}"

# --- Stage Weather language files as fallback (the bundle already carries
# --- Resources/lang; the app also checks /usr/share/weather/lang) ---
mkdir -p "${lang_dest}"
if [[ -d "${weather_dir}/lang" ]]; then
  cp -f "${weather_dir}/lang/en_us.json" "${lang_dest}/en_us.json"
  cp -f "${weather_dir}/lang/de_de.json" "${lang_dest}/de_de.json"
  chmod 0644 "${lang_dest}/en_us.json" "${lang_dest}/de_de.json"
  echo "==> Weather lang -> ${lang_dest}"
fi

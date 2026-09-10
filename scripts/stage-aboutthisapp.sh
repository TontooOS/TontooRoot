#!/usr/bin/env bash
# Build the AboutThisApp app with TBuild and stage it into the live ISO
# airootfs as an extracted folder at /System/Applications/AboutThisApp.app
# (no ZIP on the ISO, no symlink, no service).
#
# build-iso.sh invokes this before mkarchiso.
set -euo pipefail

# Accepts --github-actions (forwarded by build-iso.sh).
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
dest_dir="${apps_dir}/AboutThisApp.app"

# --- Locate the AboutThisApp project ---
about_dir=""
for candidate in \
  "${base_dir}/../TontooMicroApps/AboutThisApp" \
  "${base_dir}/TontooMicroApps/AboutThisApp" \
  "${ABOUTTHISAPP_DIR:-/nonexistent}"; do
  if [[ -f "${candidate}/tontoo.proj" ]]; then
    about_dir="${candidate}"
    break
  fi
done

if [[ -z "${about_dir}" ]]; then
  echo "stage-aboutthisapp: AboutThisApp project (tontoo.proj) not found; skipping staging" >&2
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
    echo "stage-aboutthisapp: TBuild not found; skipping staging" >&2
    exit 0
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    echo "stage-aboutthisapp: cargo not found; skipping staging" >&2
    exit 0
  fi
  echo "==> Building tbuild..."
  (cd "${tbuild_src}" && cargo build --release)
  tbuild_bin="${tbuild_src}/target/release/tbuild"
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-aboutthisapp: cargo not found; skipping staging" >&2
  exit 0
fi

# --- Build the .app bundle with TBuild ---
out_dir="$(mktemp -d)"
trap 'rm -rf "${out_dir}"' EXIT
echo "==> Building AboutThisApp.app with TBuild (${about_dir})..."
"${tbuild_bin}" app "${about_dir}" --out "${out_dir}"

app_zip="${out_dir}/AboutThisApp.app"
if [[ ! -f "${app_zip}" ]]; then
  echo "WARNING: stage-aboutthisapp: TBuild did not produce ${app_zip}, skipping staging." >&2
  exit 0
fi

# --- Extract the bundle as a folder into /System/Applications/AboutThisApp.app ---
# The .app is a ZIP archive with a top-level `AboutThisApp.app/` directory.
rm -rf "${dest_dir}"
mkdir -p "${apps_dir}"
python3 - "${app_zip}" "${apps_dir}" <<'EOF'
import sys
import zipfile

zip_path, dest_root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as z:
    for info in z.infolist():
        name = info.filename
        # Strip the top-level `AboutThisApp.app/` prefix
        parts = name.split('/', 1)
        if len(parts) != 2 or not parts[1]:
            continue
        target = dest_root + '/AboutThisApp.app/' + parts[1]
        if info.is_dir():
            __import__('os').makedirs(target, exist_ok=True)
        else:
            __import__('os').makedirs(__import__('os').path.dirname(target), exist_ok=True)
            with open(target, 'wb') as f:
                f.write(z.read(name))
EOF

# The bundle binary must stay executable (squashfs preserves staging perms).
# Binary name comes from Cargo.toml [[bin]] (about-this-app); chmod everything
# under App/ so renames never break staging.
if [[ -d "${dest_dir}/App" ]]; then
  chmod 0755 "${dest_dir}/App/"* 2>/dev/null || true
fi
chmod 0755 "${dest_dir}" 2>/dev/null || true
echo "==> AboutThisApp.app folder -> ${dest_dir}"

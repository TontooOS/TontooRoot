#!/usr/bin/env bash
# Build the SystemOverview app with TBuild and stage it into the live ISO
# airootfs as an extracted folder at /System/Applications/systemoverview.app
# (no ZIP on the ISO). Also links it system-wide as
# /Applications/SystemOverview.app (top-level system path, no per-user link).
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
dest_dir="${apps_dir}/systemoverview.app"
system_link="${profile_dir}/airootfs/Applications/SystemOverview.app"

# --- Locate the SystemOverview project ---
overview_dir=""
for candidate in \
  "${base_dir}/../TontooMicroApps/SystemOverview" \
  "${base_dir}/TontooMicroApps/SystemOverview" \
  "${SYSTEMOVERVIEW_DIR:-/nonexistent}"; do
  if [[ -f "${candidate}/tontoo.proj" ]]; then
    overview_dir="${candidate}"
    break
  fi
done

if [[ -z "${overview_dir}" ]]; then
  echo "stage-systemoverview: SystemOverview project (tontoo.proj) not found; skipping staging" >&2
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
    echo "stage-systemoverview: TBuild not found; skipping staging" >&2
    exit 0
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    echo "stage-systemoverview: cargo not found; skipping staging" >&2
    exit 0
  fi
  echo "==> Building tbuild..."
  (cd "${tbuild_src}" && cargo build --release)
  tbuild_bin="${tbuild_src}/target/release/tbuild"
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-systemoverview: cargo not found; skipping staging" >&2
  exit 0
fi

# --- Build the .app bundle with TBuild ---
out_dir="$(mktemp -d)"
trap 'rm -rf "${out_dir}"' EXIT
echo "==> Building SystemOverview.app with TBuild (${overview_dir})..."
"${tbuild_bin}" app "${overview_dir}" --out "${out_dir}"

app_zip="${out_dir}/SystemOverview.app"
if [[ ! -f "${app_zip}" ]]; then
  echo "WARNING: stage-systemoverview: TBuild did not produce ${app_zip}, skipping staging." >&2
  exit 0
fi

# --- Extract the bundle as a folder into /System/Applications/systemoverview.app ---
# The .app is a ZIP archive with a top-level `SystemOverview.app/` directory.
rm -rf "${dest_dir}"
mkdir -p "${apps_dir}"
python3 - "${app_zip}" "${apps_dir}" <<'EOF'
import sys
import zipfile

zip_path, dest_root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as z:
    for info in z.infolist():
        name = info.filename
        # Strip the top-level `SystemOverview.app/` prefix
        parts = name.split('/', 1)
        if len(parts) != 2 or not parts[1]:
            continue
        target = dest_root + '/systemoverview.app/' + parts[1]
        if info.is_dir():
            __import__('os').makedirs(target, exist_ok=True)
        else:
            __import__('os').makedirs(__import__('os').path.dirname(target), exist_ok=True)
            with open(target, 'wb') as f:
                f.write(z.read(name))
EOF

# The bundle binary must stay executable (squashfs preserves staging perms)
if [[ -f "${dest_dir}/App/systemoverview" ]]; then
  chmod 0755 "${dest_dir}/App/systemoverview"
fi
chmod 0755 "${dest_dir}" 2>/dev/null || true
echo "==> systemoverview.app folder -> ${dest_dir}"

# --- Link /Applications/SystemOverview.app system-wide (top-level system path) ---
mkdir -p "$(dirname "${system_link}")"
ln -sfn /System/Applications/systemoverview.app "${system_link}"
echo "==> system link -> ${system_link}"

# --- Remove the legacy per-user link (replaced by the system link above) ---
rm -f "${profile_dir}/airootfs/etc/skel/Applications/SystemOverview.app"

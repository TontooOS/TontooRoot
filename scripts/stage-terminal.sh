#!/usr/bin/env bash
# Build the TontooOS Terminal app with TBuild and stage it into the
# live ISO airootfs as an extracted bundle at /Applications/Terminal.app.
#
# Unlike the system apps under /System/Applications (Menubar, SystemOverview,
# AboutThisApp), Terminal is a user-facing app and lives at the top-level
# /Applications path. Launched on demand via tapp, no service, no symlink.
#
# build-iso.sh invokes this before mkarchiso.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
profile_dir="${base_dir}/BaseOS/archiso"
apps_dir="${profile_dir}/airootfs/Applications"
dest_dir="${apps_dir}/Terminal.app"
lang_dest="${profile_dir}/airootfs/usr/share/terminal/lang"
prompt_dest="${profile_dir}/airootfs/usr/share/terminal/tontoo-prompt.zsh"

# --- Locate the Terminal project ---
terminal_dir=""
for candidate in \
  "${base_dir}/../TontooMicroApps/Terminal" \
  "${TERMINAL_DIR:-/nonexistent}"; do
  if [[ -f "${candidate}/tontoo.proj" ]]; then
    terminal_dir="${candidate}"
    break
  fi
done

if [[ -z "${terminal_dir}" ]]; then
  echo "stage-terminal: Terminal project (tontoo.proj) not found; skipping terminal staging" >&2
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
    echo "stage-terminal: TBuild not found; skipping terminal staging" >&2
    exit 0
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    echo "stage-terminal: cargo not found; skipping terminal staging" >&2
    exit 0
  fi
  echo "==> Building tbuild..."
  (cd "${tbuild_src}" && cargo build --release)
  tbuild_bin="${tbuild_src}/target/release/tbuild"
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "stage-terminal: cargo not found; skipping terminal staging" >&2
  exit 0
fi

# --- Build the .app bundle with TBuild ---
out_dir="$(mktemp -d)"
trap 'rm -rf "${out_dir}"' EXIT
echo "==> Building Terminal.app with TBuild (${terminal_dir})..."
"${tbuild_bin}" app "${terminal_dir}" --out "${out_dir}"

app_zip="${out_dir}/Terminal.app"
if [[ ! -f "${app_zip}" ]]; then
  echo "WARNING: stage-terminal: TBuild did not produce ${app_zip}, skipping terminal staging." >&2
  exit 0
fi

# --- Extract the bundle into /Applications/Terminal.app ---
# The .app is a ZIP archive with a top-level `Terminal.app/` directory.
rm -rf "${dest_dir}"
mkdir -p "${apps_dir}"
python3 - "${app_zip}" "${apps_dir}" <<'EOF'
import sys
import zipfile

zip_path, dest_root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as z:
    for info in z.infolist():
        name = info.filename
        # Strip the top-level `Terminal.app/` prefix
        parts = name.split('/', 1)
        if len(parts) != 2 or not parts[1]:
            continue
        target = dest_root + '/Terminal.app/' + parts[1]
        if info.is_dir():
            __import__('os').makedirs(target, exist_ok=True)
        else:
            __import__('os').makedirs(__import__('os').path.dirname(target), exist_ok=True)
            with open(target, 'wb') as f:
                f.write(z.read(name))
EOF

# The bundle binary must stay executable (squashfs preserves staging perms)
if [[ -f "${dest_dir}/App/terminal" ]]; then
  chmod 0755 "${dest_dir}/App/terminal"
fi
chmod 0755 "${dest_dir}" 2>/dev/null || true
echo "==> Terminal.app bundle -> ${dest_dir}"

# --- Stage Terminal language files as fallback (the bundle already carries
# --- Resources/lang; the app also checks /usr/share/terminal/lang) ---
mkdir -p "${lang_dest}"
if [[ -d "${terminal_dir}/lang" ]]; then
  cp -f "${terminal_dir}/lang/en_us.json" "${lang_dest}/en_us.json"
  cp -f "${terminal_dir}/lang/de_de.json" "${lang_dest}/de_de.json"
  chmod 0644 "${lang_dest}/en_us.json" "${lang_dest}/de_de.json"
  echo "==> Terminal lang -> ${lang_dest}"
fi

# --- Stage the green prompt (fallback lookup path of the app) ---
if [[ -f "${terminal_dir}/Resources/tontoo-prompt.zsh" ]]; then
  cp -f "${terminal_dir}/Resources/tontoo-prompt.zsh" "${prompt_dest}"
  chmod 0644 "${prompt_dest}"
  echo "==> Terminal prompt -> ${prompt_dest}"
fi

#!/usr/bin/env bash
set -euo pipefail

# Accepts --github-actions (forwarded by build-iso.sh). In that mode the
# framework sources are pre-cloned next to this repo, so the Windows-only
# sibling default below is replaced with the in-workspace path.
GITHUB_ACTIONS_BUILD=0
for arg in "$@"; do
  case "${arg}" in
    --github-actions)
      GITHUB_ACTIONS_BUILD=1
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "stage-frameworks: must run on Linux (WSL)." >&2
  exit 1
fi

log() {
  local ts
  ts="$(date '+%H:%M:%S')"
  echo "[${ts}] $*"
}

error() {
  local ts
  ts="$(date '+%H:%M:%S')"
  echo "[${ts}] ERROR: $*" >&2
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
profile_dir="${base_dir}/BaseOS/archiso"
airootfs_dir="${profile_dir}/airootfs"
framework_dir="${airootfs_dir}/Library/System"

# Framework sources live locally in the TontooLibs folder - no GitHub.
libs_src=""
if [[ "${GITHUB_ACTIONS_BUILD}" -eq 1 ]]; then
  libs_src="${TONTOO_LIBS_SRC:-${base_dir}/TontooLibs}"
else
  libs_src="${TONTOO_LIBS_SRC:-/mnt/c/Users/arlo1/Documents/TontooLibs}"
fi

# System framework location on the build machine (and on TontooOS). Framework
# crates reference each other via absolute path deps like
# `/Library/System/uikit`, so sources must be staged here before dependents build.
system_dir="/Library/System"

log_file="${base_dir}/BaseOS/out/stage-frameworks.log"
mkdir -p "$(dirname "${log_file}")" "${framework_dir}" "${system_dir}"

exec > >(tee -a "${log_file}") 2>&1

log "=========================================="
log "stage-frameworks started (local sources: ${libs_src})"
log "=========================================="

if [[ ! -d "${libs_src}" ]]; then
  error "TontooLibs source folder not found at ${libs_src}"
  exit 1
fi

# "system-name:RepoDir[:so-name]" in dependency order. Each entry's path
# dependencies must appear before it: fishfile before coredata, uikit needs
# uikitdynamics, webkit/tontooui need uikit + corelocation/coreicon, mapskit
# needs uikit + corelocation, weatherkit needs corelocation.
# so-name defaults to system-name with '-' -> '_' (cargo lib naming); it is
# only needed when the cargo lib name differs (e.g. launchpad-lib).
FRAMEWORKS=(
  "fishfile:FishFile"
  "coredata:CoreData"
  "coresettings:CoreSettings"
  "corewindows:CoreWindows"
  "accessibility:Accessibility"
  "corelocation:CoreLocation"
  "coreicon:CoreIcon"
  "foundation:Foundation"
  "networkkit:NetworkKit"
  "uikitdynamics:UIKitDynamics"
  "uikit:UIKit"
  "webkit:WebKit"
  "tontooui:TontooUI"
  "mapskit:MapsKit"
  "weatherkit:WeatherKit"
  "launchpad:LaunchPad:launchpad_lib"
)

stage_sources() { # stage_sources <RepoDir> <system-name>
  local src="${libs_src}/$1"
  local dst="${system_dir}/$2"
  if [[ ! -f "${src}/Cargo.toml" ]]; then
    error "No Cargo.toml in ${src}"
    return 1
  fi
  rm -rf "${dst}"
  mkdir -p "${dst}"
  tar -C "${src}" --exclude=.git --exclude=target -cf - . | tar -C "${dst}" -xf -
}

stage_resources() { # stage_resources <RepoDir> <system-name>
  # Copies runtime resources (icons, branding assets, lang files, ...) next
  # to the .library file as a sidecar folder:
  #   /Library/System/<name>.resources/{assets,lang,...}
  # staged both into airootfs and into the live /Library/System.
  # Best-effort: never fails the framework build.
  local repo_dir="$1"
  local name="$2"
  local src="${libs_src}/${repo_dir}"
  local res_dst="${framework_dir}/${name}.resources"
  local sys_dst="${system_dir}/${name}.resources"
  rm -rf "${res_dst}"
  mkdir -p "${res_dst}"
  local copied=0
  local d
  for d in assets lang Resources resources fonts images icons data; do
    if [[ -d "${src}/${d}" ]]; then
      cp -a "${src}/${d}" "${res_dst}/${d}" 2>/dev/null || true
      copied=1
    fi
  done
  # Headers are useful for debugging on device; keep them out of the ISO
  # if they get too big? No - keep it simple, skip Headers (source-level).
  if [[ "${copied}" -eq 1 ]]; then
    rm -rf "${sys_dst}"
    mkdir -p "${sys_dst}"
    cp -a "${res_dst}/." "${sys_dst}/" 2>/dev/null || true
    log "  Resources staged -> ${framework_dir}/${name}.resources ($(du -sh "${res_dst}" 2>/dev/null | cut -f1))"
  else
    log "  No resources found in ${src} (no assets/lang/... dir), skipping."
    rmdir "${res_dst}" 2>/dev/null || true
  fi
}

build_framework() { # build_framework <RepoDir> <system-name> [so-name]
  local repo_dir="$1"
  local name="$2"
  local so_base="${3:-$2}"
  # cargo converts '-' to '_' in lib file names.
  so_base="${so_base//-/_}"
  local lib_name="${name}.library"
  local src="${libs_src}/${repo_dir}"
  local start_time end_time duration

  log "------------------------------------------"
  log "START: ${name} from ${src}"
  log "------------------------------------------"
  start_time=$(date +%s)

  log "[1/5] Staging sources to ${system_dir}/${name}..."
  stage_sources "${repo_dir}" "${name}"

  cd "${src}"

  log "[2/5] Checking Cargo.toml..."
  if [[ ! -f "Cargo.toml" ]]; then
    error "No Cargo.toml found"
    return 1
  fi
  log "  Package: $(grep '^name' Cargo.toml | head -1)"
  log "  Version: $(grep '^version' Cargo.toml | head -1)"

  log "[3/5] Building (cargo build --release)..."
  if ! cargo build --release 2>&1; then
    error "Failed to build ${name}"
    return 1
  fi

  local so_path="target/release/lib${so_base}.so"
  log "[4/6] Looking for ${so_path}..."
  if [[ ! -f "${so_path}" ]]; then
    log "  No cdylib produced by default, forcing cdylib crate-type..."
    if ! grep -q '^\[lib\]' Cargo.toml; then
      printf '\n[lib]\ncrate-type = ["cdylib", "rlib"]\n' >> Cargo.toml
    elif ! grep -q 'cdylib' Cargo.toml; then
      sed -i '/^\[lib\]/a crate-type = ["cdylib", "rlib"]' Cargo.toml
    fi
    # Keep the staged copy in sync with the patched Cargo.toml.
    cp Cargo.toml "${system_dir}/${name}/Cargo.toml"
    if ! cargo build --release 2>&1; then
      error "Failed to build ${name} as cdylib"
      return 1
    fi
  fi
  if [[ ! -f "${so_path}" ]]; then
    error "Could not find built library at ${so_path}"
    ls -la target/release/ 2>/dev/null || true
    return 1
  fi

  cp "${so_path}" "${system_dir}/${lib_name}"
  cp "${so_path}" "${framework_dir}/${lib_name}"
  rm -f "${framework_dir}/${name}.rlib"
  local size
  size=$(du -h "${framework_dir}/${lib_name}" | cut -f1)
  log "[4/6] Copied ${lib_name} (${size}) -> airootfs + ${system_dir}"

  log "[5/6] Staging resources (assets/lang/...)..."
  stage_resources "${repo_dir}" "${name}" || log "  WARNING: resource staging failed for ${name}, continuing."

  log "[6/6] Done"

  end_time=$(date +%s)
  duration=$((end_time - start_time))
  log "DONE: ${name} (${duration}s)"
  log "  -> ${framework_dir}/${lib_name}"
  log "  -> ${system_dir}/${lib_name}"

  cd "${base_dir}"
}

for entry in "${FRAMEWORKS[@]}"; do
  name="${entry%%:*}"
  rest="${entry#*:}"
  repo="${rest%%:*}"
  so_name="${rest#*:}"
  if [[ "${so_name}" == "${repo}" ]]; then
    so_name="${name}"
  fi
  build_framework "${repo}" "${name}" "${so_name}" || echo "WARNING: framework ${name} failed, continuing." >&2
done

log "=========================================="
log "Framework staging complete."
log "=========================================="
log "Libraries in ${framework_dir}:"
find "${framework_dir}" -maxdepth 1 -type f 2>/dev/null | sort
log "Resources in ${framework_dir}:"
find "${framework_dir}" -maxdepth 1 -type d -name "*.resources" 2>/dev/null | sort

#!/usr/bin/env bash
set -euo pipefail

# Accepts --github-actions (forwarded by build-iso.sh). Cursor sources are
# vendored inside this repo, so this script needs no path changes.
GITHUB_ACTIONS_BUILD=0
for arg in "$@"; do
  case "${arg}" in
    --github-actions)
      GITHUB_ACTIONS_BUILD=1
      ;;
  esac
done

# Build MacTahoe cursors with shadows from SVG sources
# Requires: xcursorgen, rsvg-convert (librsvg), python3

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
src_dir="${base_dir}/BaseOS/vendor/MacTahoe-cursors/cursors/src"
themes_dest="${base_dir}/BaseOS/archiso/airootfs/usr/share/icons"

if [[ ! -d "$src_dir" ]]; then
  echo "MacTahoe cursor source not found at ${src_dir}" >&2
  exit 1
fi

SIZES=(24x24 32x32 48x48 64x64 72x72 96x96)

# Check dependencies
for cmd in xcursorgen rsvg-convert python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "  ERROR: $cmd not found - cannot build cursors" >&2
    exit 1
  fi
done

echo "==> Building MacTahoe cursors with shadows..."

# Variant: normal (light) and dark
for variant in "" "-dark"; do
  if [[ -z "$variant" ]]; then
    svg_dir="${src_dir}/svg-shadow"
    cursor_name="MacTahoe-cursors"
  else
    svg_dir="${src_dir}/svg-dark-shadow"
    cursor_name="MacTahoe-dark-cursors"
  fi

  if [[ ! -d "$svg_dir" ]]; then
    echo "  WARNING: $svg_dir not found, skipping ${cursor_name}" >&2
    continue
  fi

  echo "  -> Building ${cursor_name}..."

  # Create temp working dir
  work_dir=$(mktemp -d)
  trap 'rm -rf "$work_dir"' EXIT

  # Copy size PNGs to work dir (will be overwritten by shadow versions)
  for size in "${SIZES[@]}"; do
    mkdir -p "${work_dir}/${size}"
    if [[ -d "${src_dir}/${size}" ]]; then
      cp "${src_dir}/${size}"/*.png "${work_dir}/${size}/" 2>/dev/null || true
    fi
  done

  # Add shadows to SVGs
  echo "    Adding shadows to SVGs..."
  # Fix CRLF line endings from Windows
  sed -i 's/\r$//' "${src_dir}/../add-shadows.py" 2>/dev/null || true
  python3 "${src_dir}/../add-shadows.py" "$svg_dir" 2>/dev/null || true

  # Convert shadow SVGs to PNGs (overwrite existing)
  for size in "${SIZES[@]}"; do
    px="${size%x*}"
    for svg in "${svg_dir}"/*.svg; do
      name=$(basename "$svg" .svg)
      png_out="${work_dir}/${size}/${name}.png"
      if [[ -f "$png_out" ]]; then
        # Replace with shadow version
        rsvg-convert -w "$px" -h "$px" "$svg" -o "$png_out" 2>/dev/null || true
      fi
    done
  done

  # Build cursors using xcursorgen
  cursor_dir="${work_dir}/cursors"
  mkdir -p "$cursor_dir"

  for config_file in "${src_dir}/config/"*.cursor; do
    cursor_name_base=$(basename "$config_file" .cursor)

    # Create xcursorgen config with absolute paths
    xc_config="${work_dir}/${cursor_name_base}.xc"
    while IFS= read -r line; do
      size=$(echo "$line" | awk '{print $1}')
      hotspot_x=$(echo "$line" | awk '{print $2}')
      hotspot_y=$(echo "$line" | awk '{print $3}')
      png_path=$(echo "$line" | awk '{print $4}')

      abs_png="${work_dir}/${png_path}"
      if [[ -f "$abs_png" ]]; then
        # xcursorgen expects a plain integer size, not "WxH".
        echo "${size} ${hotspot_x} ${hotspot_y} ${abs_png}" >> "$xc_config"
      fi
    done < "$config_file"

    if [[ -f "$xc_config" ]]; then
      xcursorgen "$xc_config" > "${cursor_dir}/${cursor_name_base}" || echo "  WARNING: xcursorgen failed for ${cursor_name_base}" >&2
    fi
  done

  # Create symlinks for standard cursor names
  cd "$cursor_dir"
  ln -sf default left_ptr 2>/dev/null || true
  ln -sf default top_left_arrow 2>/dev/null || true
  ln -sf pointer hand1 2>/dev/null || true
  ln -sf pointer hand2 2>/dev/null || true
  ln -sf pointer pointing_hand 2>/dev/null || true
  ln -sf text xterm 2>/dev/null || true
  ln -sf text ibeam 2>/dev/null || true
  ln -sf move dnd-move 2>/dev/null || true
  ln -sf copy dnd-copy 2>/dev/null || true
  ln -sf alias link 2>/dev/null || true
  ln -sf not-allowed forbidden 2>/dev/null || true
  ln -sf not-allowed crossed_circle 2>/dev/null || true
  ln -sf not-allowed no-drop 2>/dev/null || true
  ln -sf help question_arrow 2>/dev/null || true
  ln -sf help left_ptr_help 2>/dev/null || true
  ln -sf help whats_this 2>/dev/null || true
  ln -sf watch left_ptr_watch 2>/dev/null || true
  ln -sf wait half-busy 2>/dev/null || true
  ln -sf size_ver sb_v_double_arrow 2>/dev/null || true
  ln -sf size_hor sb_h_double_arrow 2>/dev/null || true
  ln -sf size_fdiag nwse-resize 2>/dev/null || true
  ln -sf size_bdiag nesw-resize 2>/dev/null || true
  ln -sf size_fdiag fd_double_arrow 2>/dev/null || true
  ln -sf size_bdiag bd_double_arrow 2>/dev/null || true
  ln -sf size_ver ns-resize 2>/dev/null || true
  ln -sf size_hor ew-resize 2>/dev/null || true
  ln -sf size_ver n-resize 2>/dev/null || true
  ln -sf size_ver s-resize 2>/dev/null || true
  ln -sf size_hor e-resize 2>/dev/null || true
  ln -sf size_hor w-resize 2>/dev/null || true
  ln -sf size_ver col-resize 2>/dev/null || true
  ln -sf size_hor row-resize 2>/dev/null || true
  ln -sf size_hor split_h 2>/dev/null || true
  ln -sf size_ver split_v 2>/dev/null || true
  ln -sf size_all fleur 2>/dev/null || true
  ln -sf size_all size_all 2>/dev/null || true
  ln -sf crosshair cross 2>/dev/null || true
  ln -sf crosshair cross_reverse 2>/dev/null || true
  ln -sf crosshair diamond_cross 2>/dev/null || true
  ln -sf crosshair tcross 2>/dev/null || true
  ln -sf openhand grab 2>/dev/null || true
  ln -sf dnd-move grabbing 2>/dev/null || true
  ln -sf pencil draft 2>/dev/null || true
  ln -sf not-allowed pirate 2>/dev/null || true
  ln -sf cell plus 2>/dev/null || true
  ln -sf context-menu menu 2>/dev/null || true


  cd "$base_dir"

  # Copy built cursors to ISO filesystem
  dest_dir="${themes_dest}/${cursor_name}"
  rm -rf "${dest_dir}/cursors"
  mkdir -p "${dest_dir}/cursors"
  cp -a "${cursor_dir}/." "${dest_dir}/cursors/"

  # Copy index.theme
  cat > "${dest_dir}/index.theme" <<THEME
[Icon Theme]
Name=${cursor_name}
Name[x-test]=xx${cursor_name}xx
Comment=MacTahoe Cursor Theme
Comment[x-test]=xxMacTahoe Cursor Themexx
THEME

  # Copy scalable cursors for Wayland
  if [[ -d "${src_dir}/scalable" ]]; then
    cp -rf "${src_dir}/scalable" "${dest_dir}/cursors_scalable"
    cp -rf "${svg_dir}/default.svg" "${dest_dir}/cursors_scalable/default" 2>/dev/null || true
    cp -rf "${svg_dir}/progress"*.svg "${dest_dir}/cursors_scalable/progress" 2>/dev/null || true
    cp -rf "${svg_dir}/wait"*.svg "${dest_dir}/cursors_scalable/wait" 2>/dev/null || true
  fi

  # Count built cursors
  cursor_count=$(ls -1 "${dest_dir}/cursors/" 2>/dev/null | wc -l)
  echo "    -> ${cursor_name}: ${cursor_count} cursors built"

  # Cleanup
  rm -rf "$work_dir"
done

echo "==> Cursor build complete"

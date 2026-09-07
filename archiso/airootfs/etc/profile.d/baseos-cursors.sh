# Detect dark/light mode and set cursor accordingly
if [[ -f "${HOME}/.config/kdeglobals" ]] && \
   grep -q "colorScheme=Dark\|colorScheme= breeze-dark\|Name=Breeze Dark" "${HOME}/.config/kdeglobals" 2>/dev/null; then
  export XCURSOR_THEME=MacTahoe-dark-cursors
elif command -v gsettings >/dev/null 2>&1; then
  scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)"
  if [[ "$scheme" == "'prefer-dark'" ]]; then
    export XCURSOR_THEME=MacTahoe-dark-cursors
  else
    export XCURSOR_THEME=MacTahoe-cursors
  fi
else
  export XCURSOR_THEME=MacTahoe-cursors
fi
export XCURSOR_SIZE=24

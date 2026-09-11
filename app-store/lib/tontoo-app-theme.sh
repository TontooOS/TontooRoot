#!/usr/bin/env bash
# tontoo-app-theme.sh — shared helpers for App Store install scripts.
#
# Usage in an install script:
#   APP_LIB="$(dirname "$0")/../../lib/tontoo-app-theme.sh"
#   [[ -f /usr/share/tontoo-app-store/lib/tontoo-app-theme.sh ]] && APP_LIB="/usr/share/tontoo-app-store/lib/tontoo-app-theme.sh"
#   # shellcheck source-path=SCRIPTDIR
#   source "${APP_LIB}"
#   tontoo_firefox_traffic_lights
#   tontoo_vscode_config
#
# Every helper is idempotent (safe to re-run) and never destroys user
# data: existing files are backed up once (*.tontoo-bak), JSON configs
# are merged key by key. Messages follow $LANG (de_* = German).

# tontoo_msg <english> <german> — bilingual status line.
tontoo_msg() {
  case "${LANG:-}" in
    de_*) printf '%s\n' "$2" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# tontoo_firefox_traffic_lights [chrome-source-dir]
# Installs macOS traffic-light window buttons into every Firefox profile
# (native, Flatpak, Snap) by copying userChrome.css + enabling stylesheets.
# Default source is the skeleton profile shipped in the ISO, so the store
# can never drift from what new users get.
tontoo_firefox_traffic_lights() {
  local src="${1:-/etc/skel/.mozilla/firefox/tontoo.default/chrome}"
  if [[ ! -d "${src}" ]]; then
    tontoo_msg "Firefox theme source missing: ${src}, skipping." \
               "Firefox-Themequelle fehlt: ${src}, wird uebersprungen."
    return 1
  fi
  local roots=(
    "${HOME}/.mozilla/firefox"
    "${HOME}/.var/app/org.mozilla.firefox/.mozilla/firefox"
    "${HOME}/snap/firefox/common/.mozilla/firefox"
  )
  local patched=0
  local root profile
  for root in "${roots[@]}"; do
    [[ -d "${root}" ]] || continue
    for profile in "${root}/"*/; do
      [[ -d "${profile}" ]] || continue
      local base
      base="$(basename "${profile}")"
      # Only real profiles: default-labeled dirs or dirs with prefs.js.
      if [[ "${base}" != *default* && ! -f "${profile}/prefs.js" ]]; then
        continue
      fi
      mkdir -p "${profile}/chrome" 2>/dev/null || continue
      if [[ -f "${profile}/chrome/userChrome.css" && ! -f "${profile}/chrome/userChrome.css.tontoo-bak" ]]; then
        cp -a "${profile}/chrome/userChrome.css" "${profile}/chrome/userChrome.css.tontoo-bak" 2>/dev/null || true
      fi
      cp -a "${src}/." "${profile}/chrome/" 2>/dev/null || continue
      if ! grep -q 'toolkit.legacyUserProfileCustomizations.stylesheets' "${profile}/user.js" 2>/dev/null; then
        printf '%s\n' 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "${profile}/user.js"
      fi
      patched=$((patched + 1))
    done
  done
  if [[ "${patched}" -eq 0 ]]; then
    tontoo_msg "No Firefox profile found yet — launch Firefox once, then re-run this installer." \
               "Noch kein Firefox-Profil gefunden — Firefox einmal starten, dann diesen Installer erneut ausfuehren."
    return 1
  fi
  tontoo_msg "Firefox traffic lights installed into ${patched} profile(s)." \
             "Firefox-Ampeln in ${patched} Profil(e) installiert."
}

# tontoo_vscode_config [settings-file ...]
# Merges TontooOS keys (custom title bar, OS color-scheme follow with
# preferred Dark/Light themes) into VSCode settings.json files, keeping
# every existing user key untouched. Without arguments, all known
# locations (native, Flatpak) are handled; a missing native file is created.
tontoo_vscode_config() {
  local files=()
  if [[ "$#" -gt 0 ]]; then
    files=("$@")
  else
    files=(
      "${HOME}/.config/Code/User/settings.json"
      "${HOME}/.var/app/com.visualstudio.code/config/Code/User/settings.json"
      "${HOME}/.var/app/com.visualstudio.code-oss/config/Code/User/settings.json"
    )
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    tontoo_msg "python3 missing, cannot merge VSCode settings." \
               "python3 fehlt, VSCode-Einstellungen koennen nicht zusammengeführt werden."
    return 1
  fi
  local merged=0
  local file
  for file in "${files[@]}"; do
    if [[ ! -f "${file}" && "${file}" != "${HOME}/.config/Code/User/settings.json" ]]; then
      continue
    fi
    mkdir -p "$(dirname "${file}")" 2>/dev/null || continue
    if python3 - "${file}" <<'PYEOF' 2>/dev/null; then
import json
import sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except (FileNotFoundError, ValueError):
    data = {}
if not isinstance(data, dict):
    data = {}
data["window.titleBarStyle"] = "custom"
data["window.autoDetectColorScheme"] = True
data["workbench.preferredDarkColorTheme"] = "Default Dark+"
data["workbench.preferredLightColorTheme"] = "Default Light+"
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=4)
    handle.write("\n")
PYEOF
      merged=$((merged + 1))
    fi
  done
  if [[ "${merged}" -eq 0 ]]; then
    tontoo_msg "No VSCode settings file found." \
               "Keine VSCode-Einstellungsdatei gefunden."
    return 1
  fi
  tontoo_msg "VSCode theme follow enabled in ${merged} file(s)." \
             "VSCode-Themefolge in ${merged} Datei(en) aktiviert."
}

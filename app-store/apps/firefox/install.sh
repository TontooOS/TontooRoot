#!/usr/bin/env bash
# App Store installer: Firefox (native) + TontooOS traffic lights.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_LIB="${SCRIPT_DIR}/../../lib/tontoo-app-theme.sh"
[[ -f /usr/share/tontoo-app-store/lib/tontoo-app-theme.sh ]] && APP_LIB="/usr/share/tontoo-app-store/lib/tontoo-app-theme.sh"
# shellcheck source-path=SCRIPTDIR
source "${APP_LIB}"

tontoo_msg "Installing Firefox..." "Installiere Firefox..."
sudo pacman -S --needed --noconfirm firefox

# Traffic-light window buttons + follow the system color scheme.
# Firefox reads the MacTahoe GTK theme and the portal color-scheme
# (written by tontoo-theme-apply) on its own; only the dots need this.
tontoo_firefox_traffic_lights

tontoo_msg "Firefox installed." "Firefox installiert."

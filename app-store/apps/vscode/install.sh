#!/usr/bin/env bash
# App Store installer: VSCode (native) + system theme follow.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_LIB="${SCRIPT_DIR}/../../lib/tontoo-app-theme.sh"
[[ -f /usr/share/tontoo-app-store/lib/tontoo-app-theme.sh ]] && APP_LIB="/usr/share/tontoo-app-store/lib/tontoo-app-theme.sh"
# shellcheck source-path=SCRIPTDIR
source "${APP_LIB}"

tontoo_msg "Installing VSCode..." "Installiere VSCode..."
sudo pacman -S --needed --noconfirm code

tontoo_msg "VSCode installed." "VSCode installiert."

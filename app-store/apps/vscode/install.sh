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

# Custom title bar + follow the OS color scheme (portal value written
# by tontoo-theme-apply). Existing user keys are preserved.
tontoo_vscode_config

tontoo_msg "VSCode installed." "VSCode installiert."

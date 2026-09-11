#!/usr/bin/env bash
# App Store installer: Chromium (native).
#
# Theming needs NO per-app config here (CSD-first): Chromium reads the
# MacTahoe GTK theme colors for its own header and follows the portal
# color-scheme for prefers-color-scheme (both written by
# tontoo-theme-apply). Wayland auto-select comes from
# ~/.config/chromium-flags.conf (skeleton default).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_LIB="${SCRIPT_DIR}/../../lib/tontoo-app-theme.sh"
[[ -f /usr/share/tontoo-app-store/lib/tontoo-app-theme.sh ]] && APP_LIB="/usr/share/tontoo-app-store/lib/tontoo-app-theme.sh"
# shellcheck source-path=SCRIPTDIR
source "${APP_LIB}"

tontoo_msg "Installing Chromium..." "Installiere Chromium..."
sudo pacman -S --needed --noconfirm chromium

tontoo_msg "Chromium installed (themed automatically)." "Chromium installiert (automatisch thematisiert)."

#!/bin/sh
# TontooOS settings daemon starter - launches Settings.app via tapp.
#
# The settings daemon is a headless system service
# (TontooServices/SettingsDeamon, staged into
# /System/Daemons/Settings.app). Unlike menubar/dock it is not a Wayland
# client, so there is nothing to wait for: HOME is ensured for the
# CoreData-backed registries, then tapp takes over.
set -eu
if [ -z "${HOME:-}" ]; then
  export HOME="/root"
fi
echo "start-settingsdaemon: HOME=$HOME launching /System/Daemons/Settings.app" >&2
exec /usr/bin/tapp /System/Daemons/Settings.app

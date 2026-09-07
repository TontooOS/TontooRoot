#!/bin/sh
# TontooOS menubar starter - launches Menubar.app via tapp once the
# compositor Wayland socket is available.
#
# The menubar is an external system app (TontooProgramms/Menubar, built
# with TBuild into /System/Applications/Menubar.app). The compositor only
# reserves the top strut and renders nothing there itself.
set -eu
# --- Fix XDG_RUNTIME_DIR if not set (launchpad sets it, but manual runs or fallback need it) ---
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
  _uid=$(id -u 2>/dev/null || echo 1000)
  export XDG_RUNTIME_DIR="/run/user/$_uid"
  mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
  chown "$_uid:$_uid" "$XDG_RUNTIME_DIR" 2>/dev/null || true
  chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
fi
# Wait for the compositor Wayland socket (max ~15s) - the menubar is a
# Wayland client and cannot start before the compositor listens.
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  if ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
if ! ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1; then
  echo "start-menubar: no wayland socket in $XDG_RUNTIME_DIR after 15s" >&2
fi
# Wayland session environment for the menubar client
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-TontooOS}"
export XDG_SESSION_TYPE=wayland
export GDK_BACKEND="${GDK_BACKEND:-wayland,x11}"
echo "start-menubar: launching /System/Applications/Menubar.app" >&2
exec /usr/bin/tapp /System/Applications/Menubar.app

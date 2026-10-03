#!/bin/sh
# TontooOS dock starter - launches Dock.app via tapp once the
# compositor Wayland socket is available.
#
# The dock is an external system app (TontooProgramms/Dock, built
# with TBuild into /System/Applications/Dock.app). The compositor
# renders nothing at the bottom itself.
set -eu
# --- Fix XDG_RUNTIME_DIR if not set (launchpad sets it, but manual runs or fallback need it) ---
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
  _uid=$(id -u 2>/dev/null || echo 1000)
  export XDG_RUNTIME_DIR="/run/user/$_uid"
  mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
  chown "$_uid:$_uid" "$XDG_RUNTIME_DIR" 2>/dev/null || true
  chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
fi
# Wait for the compositor Wayland socket (max ~15s) - the dock is a
# layer-shell client and cannot start before the compositor listens.
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  if ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
if ! ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1; then
  echo "start-dock: no wayland socket in $XDG_RUNTIME_DIR after 15s" >&2
fi
# Derive WAYLAND_DISPLAY from the actual socket. Wayland clients
# require WAYLAND_DISPLAY to be set - without it the dock dies with
# "Failed to open display" and launchpad restarts it in a tight crash
# loop (this wedged the whole guest on earlier ISOs).
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for _sock in "$XDG_RUNTIME_DIR"/wayland-*; do
    case "$_sock" in
      *.lock) continue ;;
    esac
    export WAYLAND_DISPLAY="$(basename "$_sock")"
    break
  done
  unset _sock
fi
echo "start-dock: WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-<unset>} XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" >&2
# The dock is a pure layer-shell client (TontooUI): one bottom-anchored
# bar per output plus the LaunchPad overlay, positioned and clipped by
# the compositor itself. It never opens an X11 connection and never
# positions itself, so no XWayland socket and no GDK_BACKEND are needed
# (unlike the old GTK dock, which self-positioned with XMoveWindow).
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-TontooOS}"
export XDG_SESSION_TYPE=wayland
unset GDK_BACKEND
echo "start-dock: launching /System/Applications/Dock.app" >&2
exec /usr/bin/tapp /System/Applications/Dock.app

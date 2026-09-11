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
# Wayland client and cannot start before the compositor listens.
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  if ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
if ! ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1; then
  echo "start-dock: no wayland socket in $XDG_RUNTIME_DIR after 15s" >&2
fi
# Derive WAYLAND_DISPLAY from the actual socket. GTK (and most Wayland
# clients) require WAYLAND_DISPLAY to be set - without it the dock
# dies with "Failed to open display" and launchpad restarts it in a
# tight crash loop (this wedged the whole guest on earlier ISOs).
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
# The dock positions itself via X11 (XMoveWindow), so it
# must run on XWayland: wait for the X11 socket and export DISPLAY. The
# compositor's XWM honors client moves (configure_request -> space
# reposition). Plain Wayland (xdg toplevel) has no client positioning, the
# dock would be pinned at the compositor's default spot.
for i in $(seq 1 30); do
  if ls /tmp/.X11-unix/X* >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
if [ -z "${DISPLAY:-}" ]; then
  for _xsock in /tmp/.X11-unix/X*; do
    _dpy=":${_xsock#/tmp/.X11-unix/X}"
    case "$_dpy" in
      *'*'*|*']'*) continue ;;
    esac
    export DISPLAY="$_dpy"
    break
  done
  unset _xsock _dpy
fi
echo "start-dock: DISPLAY=${DISPLAY:-<unset>}" >&2
# Wayland session environment for the dock client. Unlike Menubar.app
# (layer-shell on Wayland), the dock has no layer-shell code and
# positions itself exclusively via X11 (XMoveWindow + size hints, see
# x11_place in the Dock sources). It MUST run on the X11 backend:
# under Wayland gdk_x11_surface_get_xid returns garbage, every move
# silently fails and the dock/LaunchPad land at the compositor's
# default spot (top area / random). The app itself defaults to x11
# when GDK_BACKEND is unset; pin it explicitly.
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-TontooOS}"
export XDG_SESSION_TYPE=wayland
export GDK_BACKEND=x11
echo "start-dock: launching /System/Applications/Dock.app" >&2
exec /usr/bin/tapp /System/Applications/Dock.app

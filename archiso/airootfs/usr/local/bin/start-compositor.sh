#!/bin/sh
# TontooOS compositor starter - ensures seatd is ready and plymouth releases DRM master
set -eu
# --- Fix XDG_RUNTIME_DIR if not set (launchpad sets it, but manual runs or fallback need it) ---
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
  _uid=$(id -u 2>/dev/null || echo 1000)
  export XDG_RUNTIME_DIR="/run/user/$_uid"
  mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
  chown "$_uid:$_uid" "$XDG_RUNTIME_DIR" 2>/dev/null || true
  chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
fi
# Wait for seatd socket (max 5s) - seatd may still be starting
for i in 1 2 3 4 5 6 7 8 9 10; do
  [ -S /run/seatd.sock ] && break
  sleep 0.5
done
if [ ! -S /run/seatd.sock ]; then
  echo "start-compositor: seatd.sock not found after 5s" >&2
fi
# Ensure plymouth releases DRM master before we try to become master
# Use sudo if we are not root (plymouth needs priv)
if [ "$(id -u)" -eq 0 ]; then
  plymouth deactivate 2>/dev/null || true
  plymouth quit 2>/dev/null || true
  plymouth quit --retain-splash 2>/dev/null || true
  pkill -9 plymouthd 2>/dev/null || true
  pkill -9 @lymouthd 2>/dev/null || true
  killall plymouthd 2>/dev/null || true
else
  sudo plymouth deactivate 2>/dev/null || true
  sudo plymouth quit 2>/dev/null || true
  sudo plymouth quit --retain-splash 2>/dev/null || true
  sudo pkill -9 plymouthd 2>/dev/null || true
  sudo pkill -9 @lymouthd 2>/dev/null || true
  sudo killall plymouthd 2>/dev/null || true
fi
# Wait until plymouthd is gone and no longer holds the DRM device (max 10s).
# plymouth holds the DRM master - the compositor cannot modeset until it quits.
# (seatd then reports "Could not make device fd drm master: Device or resource busy")
echo "start-compositor: quitting plymouth..." >&2
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  if ! pgrep -x plymouthd >/dev/null 2>&1 && ! pgrep -x @lymouthd >/dev/null 2>&1 && ! pgrep -f '[p]lymouthd' >/dev/null 2>&1; then
    echo "start-compositor: plymouthd gone after ~$((i * 5))00ms" >&2
    break
  fi
  if [ "$i" -eq 10 ]; then
    # Halfway: force-kill again in case quit hung
    if [ "$(id -u)" -eq 0 ]; then
      pkill -9 plymouthd 2>/dev/null || true
      pkill -9 @lymouthd 2>/dev/null || true
    else
      sudo pkill -9 plymouthd 2>/dev/null || true
      sudo pkill -9 @lymouthd 2>/dev/null || true
    fi
  fi
  sleep 0.5
done
if pgrep -f '[p]lymouthd' >/dev/null 2>&1; then
  echo "start-compositor: WARNING plymouthd still alive, compositor DRM modeset may fail" >&2
fi
sleep 0.2
echo "start-compositor: launching /usr/bin/tontoo-compositor" >&2
# Clean stale wayland locks if compositor crashed
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
  rm -f "$XDG_RUNTIME_DIR"/wayland-*.lock 2>/dev/null || true
  if ! pgrep -x tontoo-compositor >/dev/null 2>&1; then
    rm -f "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null || true
  fi
fi
exec /usr/bin/tontoo-compositor

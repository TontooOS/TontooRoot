#!/bin/sh
# TontooOS Wayland session defaults for login shells (ttyS0, sshd, etc).
# The compositor owns wayland-1; LaunchPad creates /run/user/<uid> at boot.

if [ -z "$XDG_RUNTIME_DIR" ]; then
    XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export XDG_RUNTIME_DIR
fi

if [ -z "$WAYLAND_DISPLAY" ] && [ -n "$XDG_RUNTIME_DIR" ] && [ -S "$XDG_RUNTIME_DIR/wayland-1" ]; then
    WAYLAND_DISPLAY="wayland-1"
    export WAYLAND_DISPLAY
fi

#!/bin/sh
# Registers tapp as the binfmt_misc handler for "*.app" files and refreshes
# the MIME/desktop databases so file managers offer tapp for .app bundles.
# After this runs, executing any .app file directly ("./Steam.app")
# dispatches it to /usr/bin/tapp automatically.

BINFMT_DIR=/proc/sys/fs/binfmt_misc

if [ ! -e "${BINFMT_DIR}/tapp" ]; then
  modprobe binfmt_misc 2>/dev/null || true

  if [ ! -d "${BINFMT_DIR}" ]; then
    mkdir -p "${BINFMT_DIR}"
    mount -t binfmt_misc binfmt_misc "${BINFMT_DIR}" || exit 1
  fi

  echo ':tapp:E::app::/usr/bin/tapp:' > "${BINFMT_DIR}/register"
fi

# Make "application/x-tontoo-app" (*.app -> tapp.desktop) resolvable for
# every freedesktop file manager.
update-desktop-database /usr/share/applications 2>/dev/null || true
update-mime-database /usr/share/mime >/dev/null 2>&1 || true

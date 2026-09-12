#!/usr/bin/env bash
set -euo pipefail

ensure_live_mirrorlist() {
  if [[ -f /etc/pacman.d/mirrorlist ]] && grep -Eq '^[[:space:]]*Server[[:space:]]*=' /etc/pacman.d/mirrorlist; then
    return 0
  fi
  install -d -m 0755 /etc/pacman.d
  cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://fastly.mirror.pkgbuild.com/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
EOF
}

ensure_live_keyring() {
  install -d -m 0755 /etc/pacman.d
  install -d -m 0700 /etc/pacman.d/gnupg
  chown -R root:root /etc/pacman.d/gnupg 2>/dev/null || true
  chmod -R u+rwX /etc/pacman.d/gnupg 2>/dev/null || true
  if [[ ! -f /etc/pacman.d/gnupg/pubring.gpg ]]; then
    pacman-key --init
  fi
  pacman-key --populate archlinux
}

ensure_live_mirrorlist
ensure_live_keyring

if [ ! -e /home ]; then
  ln -s /Users /home
fi

if ! id -u liveuser >/dev/null 2>&1; then
  useradd -m -d /Users/liveuser -G wheel,audio,video,input,storage,seat,render -s /bin/bash liveuser
else
  usermod -aG wheel,audio,video,input,storage,seat,render liveuser
fi

passwd -d root >/dev/null
passwd -d liveuser >/dev/null

mkdir -p /run/liveuser
chown liveuser:liveuser /run/liveuser
chmod 700 /run/liveuser

chmod 0755 /usr/local/bin/baseos-setup-session 2>/dev/null || true

# Valid machine IDs: dbus + dconf refuse empty/invalid files, so never
# copy a possibly empty /etc/machine-id over blindly.
if command -v systemd-machine-id-setup >/dev/null 2>&1; then
  systemd-machine-id-setup 2>/dev/null || true
fi
if [[ -s /etc/machine-id ]]; then
  install -Dm0644 /etc/machine-id /var/lib/dbus/machine-id
fi
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

if [[ -f /usr/share/pixmaps/tontoo-default.png ]]; then
  install -Dm0644 /usr/share/pixmaps/tontoo-default.png /Users/liveuser/.face
  chown liveuser:liveuser /Users/liveuser/.face
  install -Dm0644 /usr/share/pixmaps/tontoo-default.png /var/lib/AccountsService/icons/liveuser
  cat > /var/lib/AccountsService/users/liveuser <<EOF
[User]
Icon=/var/lib/AccountsService/icons/liveuser
SystemAccount=false
EOF
fi

if [[ -d /etc/skel/.config ]]; then
  install -d -m 0755 /Users/liveuser/.config
  cp -a /etc/skel/.config/. /Users/liveuser/.config/
  chown -R liveuser:liveuser /Users/liveuser/.config
fi

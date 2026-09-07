#!/usr/bin/env bash
set -euo pipefail

config_file="${1:-}"
target_mount="/mnt"

emit_progress() {
  local percent="$1"
  shift
  printf 'BASEOS_PROGRESS:%s:%s\n' "$percent" "$*"
}

log() {
  printf '%s\n' "$*"
}

fail() {
  log "ERROR: $*"
  emit_progress 0 "Installation failed"
  exit 1
}

on_error() {
  local line="$1"
  log "ERROR: Installation failed near line ${line}."
  emit_progress 0 "Installation failed"
  exit 1
}

trap 'on_error "$LINENO"' ERR

json_value() {
  local key="$1"
  local fallback="${2:-}"

  python3 - "$config_file" "$key" "$fallback" <<'PY'
import json
import sys

file, key, fallback = sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""
value = fallback

try:
    with open(file, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    cursor = data
    for segment in key.split("."):
        if isinstance(cursor, dict) and segment in cursor:
            cursor = cursor[segment]
        else:
            cursor = None
            break
    if cursor is not None and cursor != "":
        value = cursor
except Exception:
    value = fallback

if isinstance(value, bool):
    sys.stdout.write("true" if value else "false")
else:
    sys.stdout.write(str(value))
PY
}

sanitize_username() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+//; s/-+$//')"
  if [[ ! "$value" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    value="tontoo"
  fi
  printf '%s' "$value"
}

sanitize_hostname() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]_' '[:lower:]-' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//')"
  value="${value:0:63}"
  if [[ -z "$value" ]]; then
    value="tontoo-pc"
  fi
  printf '%s' "$value"
}

partition_path() {
  local disk="$1"
  local number="$2"

  if [[ "$disk" =~ (nvme[0-9]+n[0-9]+|mmcblk[0-9]+|loop[0-9]+)$ ]]; then
    printf '%sp%s' "$disk" "$number"
  else
    printf '%s%s' "$disk" "$number"
  fi
}

write_file() {
  local path="$1"
  shift
  install -Dm0644 /dev/null "${target_mount}${path}"
  printf '%s\n' "$@" > "${target_mount}${path}"
}

append_file() {
  local path="$1"
  shift
  mkdir -p "$(dirname "${target_mount}${path}")"
  printf '%s\n' "$@" >> "${target_mount}${path}"
}

copy_if_exists() {
  local source="$1"
  local destination="$2"

  if [[ -e "$source" ]]; then
    mkdir -p "$(dirname "${target_mount}${destination}")"
    cp -a "$source" "${target_mount}${destination}"
  fi
}

target_is_mounted() {
  findmnt -R "$target_mount" >/dev/null 2>&1
}

unmount_target() {
  local required="${1:-required}"
  local attempt

  sync || true

  for attempt in 1 2 3 4 5; do
    if ! target_is_mounted; then
      return 0
    fi

    if umount -R "$target_mount" >/dev/null 2>&1; then
      return 0
    fi

    log "Unmount retry ${attempt}/5: ${target_mount} is still busy."
    sleep 1
  done

  if target_is_mounted; then
    log "Warning: ${target_mount} is still busy; using lazy unmount."
    if umount -Rl "$target_mount" >/dev/null 2>&1; then
      return 0
    fi
  fi

  if [[ "$required" == "optional" ]]; then
    return 0
  fi

  fail "Could not unmount ${target_mount}. Restart the live system before retrying."
}

ensure_live_mirrorlist() {
  if [[ -f /etc/pacman.d/mirrorlist ]] && grep -Eq '^[[:space:]]*Server[[:space:]]*=' /etc/pacman.d/mirrorlist; then
    return
  fi

  install -d -m 0755 /etc/pacman.d
  cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://fastly.mirror.pkgbuild.com/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
EOF
}

ensure_live_keyring() {
  emit_progress 5 "Preparing package keyring"

  install -d -m 0755 /etc/pacman.d
  install -d -m 0700 /etc/pacman.d/gnupg
  chown -R root:root /etc/pacman.d/gnupg
  chmod -R u+rwX /etc/pacman.d/gnupg

  if [[ ! -f /etc/pacman.d/gnupg/pubring.gpg ]]; then
    pacman-key --init
  fi

  pacman-key --populate archlinux
}

preflight_package_databases() {
  emit_progress 5 "Checking package mirrors"
  ensure_live_mirrorlist
  ensure_live_keyring
  pacman -Sy --noconfirm archlinux-keyring
}

install_assets_into_target() {
  emit_progress 82 "Installing system assets"

  copy_if_exists /etc/plymouth/plymouthd.conf /etc/plymouth/plymouthd.conf
  copy_if_exists /usr/share/pixmaps/tontoo-default.png /usr/share/pixmaps/tontoo-default.png
  copy_if_exists /usr/share/icons/MacTahoe-cursors /usr/share/icons/MacTahoe-cursors
  copy_if_exists /usr/share/icons/MacTahoe-dark-cursors /usr/share/icons/MacTahoe-dark-cursors
  copy_if_exists /usr/share/icons/MacTahoe /usr/share/icons/MacTahoe
  copy_if_exists /usr/share/plymouth/themes/tontoo /usr/share/plymouth/themes/tontoo
  copy_if_exists /usr/share/sounds/tontoosounds /usr/share/sounds/tontoosounds
  copy_if_exists /usr/share/tontoo-wallpapers /usr/share/tontoo-wallpapers
  copy_if_exists /etc/profile.d/baseos-cursors.sh /etc/profile.d/baseos-cursors.sh
  copy_if_exists /etc/environment /etc/environment
  copy_if_exists /etc/X11/xorg.conf.d/90-cursor-theme.conf /etc/X11/xorg.conf.d/90-cursor-theme.conf
  copy_if_exists /etc/gtk-3.0/settings.ini /etc/gtk-3.0/settings.ini
  copy_if_exists /etc/gtk-4.0/settings.ini /etc/gtk-4.0/settings.ini

  # Wallpapers + backgrounds
  copy_if_exists /usr/share/backgrounds /usr/share/backgrounds
  copy_if_exists /usr/share/wallpapers /usr/share/wallpapers

  # Cursor themes
  copy_if_exists /usr/share/icons/MacTahoe-cursors /usr/share/icons/MacTahoe-cursors
  copy_if_exists /usr/share/icons/MacTahoe-dark-cursors /usr/share/icons/MacTahoe-dark-cursors
  copy_if_exists /usr/share/icons/default /usr/share/icons/default

  # Icon theme
  copy_if_exists /usr/share/icons/MacTahoe /usr/share/icons/MacTahoe

  # X11 cursor config
  copy_if_exists /etc/X11/Xresources.d/50-baseos-cursors /etc/X11/Xresources.d/50-baseos-cursors

   # User default configs
   copy_if_exists /etc/skel/.config /Users/${username}/.config

   if [[ -d /etc/skel/.config ]]; then
     install -d -m 0755 "${target_mount}/Users/${username}/.config"
     cp -a /etc/skel/.config/. "${target_mount}/Users/${username}/.config/"
     arch-chroot "$target_mount" chown -R "${username}:${username}" "/Users/${username}/.config"
   fi

   # Firefox default profile (native Firefox reads ~/.mozilla, not ~/.config).
   copy_if_exists /etc/skel/.mozilla /Users/${username}/.mozilla

   if [[ -d /etc/skel/.mozilla ]]; then
     install -d -m 0755 "${target_mount}/Users/${username}/.mozilla"
     cp -a /etc/skel/.mozilla/. "${target_mount}/Users/${username}/.mozilla/"
     arch-chroot "$target_mount" chown -R "${username}:${username}" "/Users/${username}/.mozilla"
   fi

}

install_compositor_into_target() {
  emit_progress 83 "Installing compositor"

  copy_if_exists /usr/bin/tontoo-compositor /usr/bin/tontoo-compositor
  chmod 0755 "${target_mount}/usr/bin/tontoo-compositor" 2>/dev/null || true

  # Install LaunchPad service for compositor
  mkdir -p "${target_mount}/Library/System/Launchpads"
  cat > "${target_mount}/Library/System/Launchpads/compositor.service" <<EOF
name: compositor
execute: /usr/bin/tontoo-compositor
type: sys
user: ${username}
depends_on:
  - seatd
  - pipewire
restart: true
EOF
}

install_menubar_into_target() {
  emit_progress 83 "Installing system menubar"

  # Menubar.app system bundle (external top bar, built with TBuild)
  if [[ -d /System/Applications/Menubar.app ]]; then
    mkdir -p "${target_mount}/System/Applications"
    cp -a /System/Applications/Menubar.app "${target_mount}/System/Applications/Menubar.app"
    chmod 0755 "${target_mount}/System/Applications/Menubar.app/App/menubar" 2>/dev/null || true
  fi

  # Menubar starter (waits for the compositor Wayland socket, then tapp)
  copy_if_exists /usr/local/bin/start-menubar.sh /usr/local/bin/start-menubar.sh
  chmod 0755 "${target_mount}/usr/local/bin/start-menubar.sh" 2>/dev/null || true

  # Menubar language files
  if [[ -d /usr/share/tontoo/menubar/lang ]]; then
    mkdir -p "${target_mount}/usr/share/tontoo/menubar/lang"
    cp -a /usr/share/tontoo/menubar/lang/. "${target_mount}/usr/share/tontoo/menubar/lang/"
  fi

  # Install LaunchPad service for menubar (per-user on installed systems,
  # which is the multi-user-ready form of the live `liveuser` service)
  mkdir -p "${target_mount}/Library/System/Launchpads"
  cat > "${target_mount}/Library/System/Launchpads/menubar.service" <<EOF
name: menubar
execute: /usr/local/bin/start-menubar.sh
type: sys
user: ${username}
depends_on:
  - compositor
  - live-setup
restart: true
EOF
}

install_fishperms_into_target() {
  emit_progress 85 "Installing system protection"

  # App runner + binfmt registration script
  copy_if_exists /usr/bin/tapp /usr/bin/tapp
  chmod 0755 "${target_mount}/usr/bin/tapp" 2>/dev/null || true
  copy_if_exists /usr/local/bin/tapp-binfmt.sh /usr/local/bin/tapp-binfmt.sh
  chmod 0755 "${target_mount}/usr/local/bin/tapp-binfmt.sh" 2>/dev/null || true

  # FishPerms integrity daemon + CLI + popup + sandbox supervisor
  copy_if_exists /usr/bin/fishperms-daemon /usr/bin/fishperms-daemon
  copy_if_exists /usr/bin/fishpermctl /usr/bin/fishpermctl
  copy_if_exists /usr/bin/fishperms-prompt /usr/bin/fishperms-prompt
  copy_if_exists /usr/bin/fishbox /usr/bin/fishbox
  chmod 0755 "${target_mount}/usr/bin/fishperms-daemon" 2>/dev/null || true
  chmod 0755 "${target_mount}/usr/bin/fishpermctl" 2>/dev/null || true
  chmod 0755 "${target_mount}/usr/bin/fishperms-prompt" 2>/dev/null || true
  chmod 0755 "${target_mount}/usr/bin/fishbox" 2>/dev/null || true

  # Protection policy + trusted executables list (SIP-style)
  if [[ -d /Library/Preferences/FishPerms ]]; then
    mkdir -p "${target_mount}/Library/Preferences/FishPerms"
    cp -a /Library/Preferences/FishPerms/protected.conf \
      "${target_mount}/Library/Preferences/FishPerms/protected.conf" 2>/dev/null || true
    cp -a /Library/Preferences/FishPerms/trusted.conf \
      "${target_mount}/Library/Preferences/FishPerms/trusted.conf" 2>/dev/null || true
  fi

  # LaunchPad services: binfmt registration + integrity locks at boot
  mkdir -p "${target_mount}/Library/System/Launchpads"
  for svc in FishPerms tapp-binfmt; do
    if [[ -f "/Library/System/Launchpads/${svc}.service" ]]; then
      cp -a "/Library/System/Launchpads/${svc}.service" \
        "${target_mount}/Library/System/Launchpads/${svc}.service"
    fi
  done
}

configure_boot_splash_into_target() {
  emit_progress 84 "Configuring boot splash"

  install -Dm0644 /dev/null "${target_mount}/etc/mkinitcpio.conf.d/tontooos.conf"
  cat > "${target_mount}/etc/mkinitcpio.conf.d/tontooos.conf" <<'EOF'
HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
EOF

  if [[ -f "${target_mount}/etc/mkinitcpio.conf" ]]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' "${target_mount}/etc/mkinitcpio.conf"
  fi

  if [[ -f "${target_mount}/etc/default/grub" ]]; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog plymouth.ignore-serial-consoles init=\/usr\/bin\/launchpad-daemon"/' "${target_mount}/etc/default/grub"
  fi

  arch-chroot "$target_mount" mkinitcpio -P
}

configure_first_boot_reboot() {
  emit_progress 90 "Preparing first boot"

  # Copy LaunchPad binaries
  copy_if_exists /usr/bin/launchpad-daemon /usr/bin/launchpad-daemon
  copy_if_exists /usr/bin/launchctl /usr/bin/launchctl
  chmod 0755 "${target_mount}/usr/bin/launchpad-daemon" 2>/dev/null || true
  chmod 0755 "${target_mount}/usr/bin/launchctl" 2>/dev/null || true

  # Install LaunchPad service YAMLs
  mkdir -p "${target_mount}/Library/System/Launchpads"
  for svc in seatd dbus networkmanager pipewire pipewire-pulse wireplumber FishPerms tapp-binfmt; do
    if [[ -f "/Library/System/Launchpads/${svc}.service" ]]; then
      cp -a "/Library/System/Launchpads/${svc}.service" \
        "${target_mount}/Library/System/Launchpads/${svc}.service"
    fi
  done

  # Create first-boot marker script
  cat > "${target_mount}/usr/local/lib/tontooos-firstboot.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

marker="/var/lib/tontooos/firstboot.done"

if [[ -e "$marker" ]]; then
  exit 0
fi

mkdir -p /var/lib/tontooos
touch "$marker"
reboot
EOF
  chmod 0755 "${target_mount}/usr/local/lib/tontooos-firstboot.sh"
}

if [[ -z "$config_file" || ! -f "$config_file" ]]; then
  fail "Missing installer configuration."
fi

if [[ "$(id -u)" != "0" ]]; then
  fail "Installer must run as root."
fi

disk="$(json_value selectedHarddrive)"
username="$(sanitize_username "$(json_value username tontoo)")"
first_name="$(json_value firstName)"
last_name="$(json_value lastName)"
full_name="$(printf '%s %s' "$first_name" "$last_name" | sed -E 's/^ +//; s/ +$//; s/  +/ /g')"
computer_name="$(sanitize_hostname "$(json_value computerName tontoo-pc)")"
password="$(json_value password)"
language="$(json_value language en)"
keyboard="$(json_value keyboard us)"
timezone="$(json_value timezone Europe/Berlin)"
ssh_enabled="$(json_value sshEnabled false)"
ssh_root_login="$(json_value sshRootLogin false)"
ssh_port="$(json_value sshPort 22)"

if [[ -z "$disk" || ! "$disk" == /dev/* || ! -b "$disk" ]]; then
  fail "Selected harddrive is not available: ${disk:-none}"
fi

if [[ -z "$password" ]]; then
  fail "A password is required for the first user."
fi

if [[ ! "$ssh_port" =~ ^[0-9]+$ || "$ssh_port" -lt 1 || "$ssh_port" -gt 65535 ]]; then
  ssh_port="22"
fi

if [[ ! -e "/usr/share/zoneinfo/${timezone}" ]]; then
  timezone="Europe/Berlin"
fi

case "$keyboard" in
  de) vconsole_keymap="de-latin1" ;;
  *) vconsole_keymap="us" ;;
esac

case "$language" in
  de) locale_lang="de_DE.UTF-8" ;;
  *) locale_lang="en_US.UTF-8" ;;
esac

esp_part="$(partition_path "$disk" 2)"
root_part="$(partition_path "$disk" 3)"

packages=(
  accountsservice
  alsa-utils
  archlinux-keyring
  base
  bash
  btrfs-progs
  chromium
  curl
  dbus-broker
  dosfstools
  e2fsprogs
  efibootmgr
  electron
  exfatprogs
  f2fs-tools
  git
  glib2
  gptfdisk
  grub
  gtk3
  gvfs
  inter-font
  linux
  linux-firmware
  mesa
  mtools
  nano
  networkmanager
  noto-fonts
  noto-fonts-emoji
  ntfs-3g
  openssh
  open-vm-tools
  otf-font-awesome
  pavucontrol
  pipewire
  pipewire-alsa
  pipewire-pulse
  plymouth
  polkit
  python
  python-pip
  qemu-guest-agent

  seatd
  spice-vdagent
  sudo
  ttf-dejavu
  util-linux
  virtualbox-guest-utils
  wireplumber
  wl-clipboard
  xdg-desktop-portal
  xdg-user-dirs
  xdg-utils
  xf86-video-fbdev
  xf86-video-qxl
  xf86-video-vesa
  xfsprogs
  xorg-server
  xorg-xwayland
  zsh
)

log "TontooOS installer started."
log "Target disk: $disk"
log "Target user: $username"
emit_progress 3 "Preparing installer"

preflight_package_databases

swapoff -a >/dev/null 2>&1 || true
unmount_target optional

emit_progress 8 "Erasing selected disk"
sgdisk --zap-all "$disk"
wipefs -af "$disk"
parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart BIOSBOOT 1MiB 3MiB
parted -s "$disk" set 1 bios_grub on
parted -s "$disk" mkpart ESP fat32 3MiB 1027MiB
parted -s "$disk" set 2 esp on
parted -s "$disk" mkpart ROOT ext4 1027MiB 100%
partprobe "$disk"
udevadm settle

emit_progress 18 "Formatting partitions"
mkfs.fat -F32 "$esp_part"
mkfs.ext4 -F "$root_part"

# Enable the ext4 verity feature so FishPerms can seal system files
# with fs-verity. Harmless warning when the mkfs.ext4 build lacks it.
tune2fs -O verity "$root_part" 2>/dev/null || log "Warning: ext4 verity feature could not be enabled."

emit_progress 24 "Mounting target system"
mount "$root_part" "$target_mount"
mkdir -p "${target_mount}/boot"
mount "$esp_part" "${target_mount}/boot"

emit_progress 36 "Installing base system and desktop"
pacstrap -K "$target_mount" "${packages[@]}"

emit_progress 58 "Writing filesystem table"
genfstab -U "$target_mount" > "${target_mount}/etc/fstab"

emit_progress 62 "Configuring language and keyboard"
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' "${target_mount}/etc/locale.gen"
sed -i 's/^#\(de_DE.UTF-8 UTF-8\)/\1/' "${target_mount}/etc/locale.gen"
arch-chroot "$target_mount" locale-gen
write_file /etc/locale.conf "LANG=${locale_lang}"
write_file /etc/vconsole.conf "KEYMAP=${vconsole_keymap}"
ln -sfn "/usr/share/zoneinfo/${timezone}" "${target_mount}/etc/localtime"
arch-chroot "$target_mount" hwclock --systohc

emit_progress 66 "Configuring users"
write_file /etc/hostname "$computer_name"
write_file /etc/hosts \
  "127.0.0.1 localhost" \
  "::1 localhost" \
  "127.0.1.1 ${computer_name}.localdomain ${computer_name}"

for target_group in wheel audio video input storage seat; do
  arch-chroot "$target_mount" groupadd -r "$target_group" >/dev/null 2>&1 || true
done

arch-chroot "$target_mount" groupadd -r autologin >/dev/null 2>&1 || true
arch-chroot "$target_mount" useradd -m -d /Users/$username -G wheel,audio,video,input,storage,seat,autologin -c "$full_name" -s /bin/bash "$username"
printf '%s:%s\n' "$username" "$password" | arch-chroot "$target_mount" chpasswd

if [[ "$ssh_root_login" == "true" ]]; then
  printf 'root:%s\n' "$password" | arch-chroot "$target_mount" chpasswd
fi

install -Dm0440 /dev/null "${target_mount}/etc/sudoers.d/00-wheel"
printf '%%wheel ALL=(ALL:ALL) ALL\n' > "${target_mount}/etc/sudoers.d/00-wheel"

if [[ ! -e "${target_mount}/home" ]]; then
   ln -s /Users "${target_mount}/home"
 fi

 if [[ -f /usr/share/pixmaps/tontoo-default.png ]]; then
   install -Dm0644 /usr/share/pixmaps/tontoo-default.png "${target_mount}/Users/${username}/.face"
   arch-chroot "$target_mount" chown "${username}:${username}" "/Users/${username}/.face"
  install -Dm0644 /usr/share/pixmaps/tontoo-default.png "${target_mount}/var/lib/AccountsService/icons/${username}"
  install -Dm0644 /dev/null "${target_mount}/var/lib/AccountsService/users/${username}"
  cat > "${target_mount}/var/lib/AccountsService/users/${username}" <<EOF
[User]
Icon=/var/lib/AccountsService/icons/${username}
SystemAccount=false
BackgroundFile=/usr/share/backgrounds/27-Golden-Gate.png
EOF
fi

emit_progress 70 "Configuring services"

# Copy LaunchPad binaries to target
copy_if_exists /usr/bin/launchpad-daemon /usr/bin/launchpad-daemon
copy_if_exists /usr/bin/launchctl /usr/bin/launchctl
chmod 0755 "${target_mount}/usr/bin/launchpad-daemon" 2>/dev/null || true
chmod 0755 "${target_mount}/usr/bin/launchctl" 2>/dev/null || true

# Copy LaunchPad language files to target
if [[ -d /usr/share/launchpad/lang ]]; then
  mkdir -p "${target_mount}/usr/share/launchpad/lang"
  cp -a /usr/share/launchpad/lang/. "${target_mount}/usr/share/launchpad/lang/"
fi

# Install LaunchPad service YAMLs
mkdir -p "${target_mount}/Library/System/Launchpads"
for svc in seatd dbus networkmanager pipewire pipewire-pulse wireplumber compositor menubar FishPerms tapp-binfmt; do
    if [[ -f "/Library/System/Launchpads/${svc}.service" ]]; then
      cp -a "/Library/System/Launchpads/${svc}.service" \
        "${target_mount}/Library/System/Launchpads/${svc}.service"
    fi
  done

# Create user-specific service overrides if needed
if [[ "$ssh_enabled" == "true" ]]; then
  install -Dm0644 /dev/null "${target_mount}/etc/ssh/sshd_config.d/10-tontooos.conf"
  cat > "${target_mount}/etc/ssh/sshd_config.d/10-tontooos.conf" <<EOF
Port ${ssh_port}
PermitRootLogin $([[ "$ssh_root_login" == "true" ]] && printf 'yes' || printf 'no')
PasswordAuthentication yes
EOF
fi

install_assets_into_target
install_compositor_into_target
install_menubar_into_target
install_fishperms_into_target
configure_boot_splash_into_target

emit_progress 86 "Installing bootloader"
if [[ -d /sys/firmware/efi/efivars ]]; then
  arch-chroot "$target_mount" grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=TontooOS --recheck
fi

arch-chroot "$target_mount" grub-install --target=i386-pc "$disk"
arch-chroot "$target_mount" grub-mkconfig -o /boot/grub/grub.cfg

configure_first_boot_reboot

emit_progress 95 "Cleaning up"
install -d -m 0755 "${target_mount}/var/lib/tontooos"
python3 - "$config_file" > "${target_mount}/var/lib/tontooos/install-settings.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
data.pop("password", None)
data.pop("passwordRepeat", None)
sys.stdout.write(json.dumps(data, indent=2) + "\n")
PY
chmod 0600 "${target_mount}/var/lib/tontooos/install-settings.json"
arch-chroot "$target_mount" chown root:root /var/lib/tontooos/install-settings.json
sync
unmount_target

emit_progress 100 "Installation complete. Restarting"
log "Installation complete. The computer will restart now."

if [[ "${BASEOS_INSTALL_NO_REBOOT:-0}" != "1" ]]; then
  sleep 5
  reboot
fi

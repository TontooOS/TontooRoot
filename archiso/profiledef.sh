#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="arch-base-setup"
iso_label="ARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Local Arch Build"
iso_application="Neutral Arch Linux live desktop environment"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
arch="x86_64"

buildmodes=('iso')
bootmodes=(
  'bios.syslinux'
  'uefi.grub'
)

pacman_conf="pacman.conf"

airootfs_image_type="squashfs"
airootfs_image_tool_options=(
  '-comp' 'xz'
  '-b' '1M'
  '-Xdict-size' '1M'
)

file_permissions=(
  ["/Users"]="0:0:755"
  ["/Library"]="0:0:755"
  ["/Library/System"]="0:0:755"
  ["/System"]="0:0:755"
  ["/System/services"]="0:0:755"
  ["/System/User"]="0:0:755"
  ["/System/User/Wallpapers"]="0:0:755"
  ["/System/Applications"]="0:0:755"
  ["/System/Applications/Menubar.app"]="0:0:755"
  ["/System/Applications/Menubar.app/App/menubar"]="0:0:755"
  ["/System/Applications/Dock.app"]="0:0:755"
  ["/System/Applications/Dock.app/App/dock"]="0:0:755"
  ["/System/Applications/systemoverview.app"]="0:0:755"
  ["/System/Applications/systemoverview.app/App/systemoverview"]="0:0:755"
  ["/System/Applications/AboutThisApp.app"]="0:0:755"
  ["/System/Applications/AboutThisApp.app/App/about-this-app"]="0:0:755"
  ["/Applications"]="0:0:755"
  ["/Applications/SystemOverview.app"]="0:0:755"
  ["/Applications/Weather.app"]="0:0:755"
  ["/Applications/Weather.app/App/weather"]="0:0:755"
  ["/Applications/Terminal.app"]="0:0:755"
  ["/Applications/Terminal.app/App/terminal"]="0:0:755"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/00-liveuser"]="0:0:440"
  ["/usr/local/bin/baseos-setup-session"]="0:0:755"
  ["/usr/local/lib/baseos-setup/install-system.sh"]="0:0:755"
  ["/usr/local/lib/archiso/enable-live-desktop.sh"]="0:0:755"
  ["/usr/bin/tontoo-compositor"]="0:0:755"
  ["/usr/bin/launchpad-daemon"]="0:0:755"
  ["/usr/bin/launchctl"]="0:0:755"
  ["/usr/bin/fishperms-daemon"]="0:0:755"
  ["/usr/bin/fishpermctl"]="0:0:755"
  ["/usr/bin/fishperms-prompt"]="0:0:755"
  ["/usr/bin/fishbox"]="0:0:755"
  ["/usr/bin/tapp"]="0:0:755"
  ["/usr/local/bin/tapp-binfmt.sh"]="0:0:755"
  ["/usr/local/bin/start-compositor.sh"]="0:0:755"
  ["/usr/local/bin/start-menubar.sh"]="0:0:755"
  ["/usr/local/bin/start-dock.sh"]="0:0:755"
  ["/usr/local/bin/tontoo-sshd.sh"]="0:0:755"
  ["/usr/local/bin/tontoo-net-up.sh"]="0:0:755"
  ["/Library/Preferences/FishPerms"]="0:0:755"
)

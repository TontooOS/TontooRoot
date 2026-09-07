#!/usr/bin/env bash
# LaunchPad service entry for OpenSSH.
#
# The systemd sshd unit normally creates the privilege separation directory.
# With LaunchPad as PID 1 we do that here, then exec sshd in the foreground so
# LaunchPad can supervise and restart it.
#
# Host keys are pre-generated into the ISO by scripts/stage-sshd.sh, but the
# NTFS build loses Unix permissions (the private key lands as 0644 in the
# squashfs). sshd rejects world-readable keys, so we restore the mode at boot -
# overlayfs copy-up makes the chmod work on the live rootfs.
set -euo pipefail

mkdir -p /run/sshd
chmod 0755 /run/sshd

chmod 0600 /etc/ssh/ssh_host_ed25519_key 2>/dev/null || true
chmod 0644 /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || true

if [ ! -s /etc/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -q -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
fi

exec /usr/bin/sshd -D
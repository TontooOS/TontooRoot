#!/usr/bin/env bash
# Pre-generate OpenSSH host keys for the live ISO.
#
# The keys are generated here (running on Linux/WSL) instead of at first boot,
# because the boot-time `ssh-keygen -A` in the VM can block for a very long
# time without a hardware entropy source, which delays sshd startup.
#
# Creating the files from a Linux process also preserves the correct Unix
# permissions (0600 for the private key) through mkarchiso - files created on
# Windows/NTFS always land in the squashfs as 0644, which sshd rejects.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd -- "${script_dir}/../.." && pwd)"
key_dir="${base_dir}/BaseOS/archiso/airootfs/etc/ssh"

if ! command -v ssh-keygen >/dev/null 2>&1; then
  echo "stage-sshd: ssh-keygen not found; skipping host key generation" >&2
  exit 0
fi

echo "==> Staging SSH host keys..."
mkdir -p "${key_dir}"
if [ ! -f "${key_dir}/ssh_host_ed25519_key" ]; then
  ssh-keygen -q -t ed25519 -f "${key_dir}/ssh_host_ed25519_key" -N ''
  echo "==> Generated ed25519 host key"
else
  echo "==> ed25519 host key already present"
fi

chmod 0600 "${key_dir}/ssh_host_ed25519_key"
chmod 0644 "${key_dir}/ssh_host_ed25519_key.pub"
echo "==> SSH host keys -> ${key_dir}"
# LivePackages

LivePackages documents which applications ship on the TontooOS live ISO and how
the live session keeps `pacman` usable without manual repair.

## Browser

No browser ships by default. Install one on demand via `pacman`:

```bash
sudo pacman -Sy --noconfirm chromium
chromium --version
```

## Pacman Keyring Self-Heal

Fresh live boots used to fail with `keyring is not writable` and `required key
missing from keyring` because `/etc/pacman.d/gnupg` did not exist yet. Every
live boot now runs `enable-live-desktop.sh` through the `live-setup` LaunchPad
service (`System/services/live-setup.service`, type `sys`, user
`root`), which performs two idempotent steps before anything else:

| Step | Function | Behavior |
|---|---|---|
| `mirrorlist` | `ensure_live_mirrorlist` | Writes a fallback mirrorlist only when no `Server =` line exists |
| `keyring` | `ensure_live_keyring` | Creates `/etc/pacman.d/gnupg` (`0700`, `root:root`), runs `pacman-key --init` only when `pubring.gpg` is missing, then always runs `pacman-key --populate archlinux` |

The installer (`install-system.sh`) keeps its own preflight
(`ensure_live_mirrorlist`, `ensure_live_keyring`, `pacman -Sy archlinux-keyring`)
before wiping the disk, so both the live session and the install path are
covered. No automatic `pacman -Sy` runs at boot; the user refreshes databases
on demand.

## Usage / Example

On a fresh live boot, installing a package works without manual keyring repair:

```bash
ssh -p 2222 liveuser@127.0.0.1
sudo pacman -Sy --noconfirm htop
```

## Cross References

- [Installer.md](Installer.md) – target package list and install flow
- [RULE.md](RULE.md) – wiki conventions

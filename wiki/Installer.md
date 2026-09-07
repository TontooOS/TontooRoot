# Installer

The Installer is the destructive Arch installer that runs from the live ISO
after the final `Install` confirmation in the Electron setup screen. Its entry
point is `/usr/local/lib/baseos-setup/install-system.sh` (called with the JSON
settings file as `$1` and using `/mnt` as the target mount).

## Configuration Parsing

Settings arrive as JSON. `json_value` reads one dotted key with an optional
fallback and prints `true`/`false` for booleans:

```bash
disk="$(json_value selectedHarddrive)"
username="$(sanitize_username "$(json_value username tontoo)")"
ssh_port="$(json_value sshPort 22)"
```

- Implementation uses `python3`, which is already an ISO package.
- Missing files, invalid JSON, missing keys, `null` values and empty strings all
  fall back to the caller-provided default.
- No Node.js runtime is required or consulted; the installer fails early only
  when the config file is missing or when it is not run as root.

## Install Flow

1. `preflight_package_databases` refreshes the mirrorlist, the keyring and the
   `archlinux-keyring` package.
2. The selected disk is wiped (GPT, BIOSBOOT + ESP + ROOT), formatted and
   mounted at `/mnt`.
3. `pacstrap -K` installs the `packages` array, which includes `chromium`,
   `electron`, `archlinux-keyring`, `networkmanager`, `pipewire` and the desktop
   stack.
4. Locale, keyboard, timezone, hostname, users (`/Users/<name>`, `wheel` sudo),
   SSH config and LaunchPad services are written to the target.
5. System assets (Plymouth theme, icons, sounds, wallpapers) are written to
   the target; no JavaScript runtime is installed or linked.
6. GRUB (UEFI + BIOS), a first-boot finalization service and a sanitized
   `install-settings.json` (password fields removed via `python3`) finish the
   install, then the machine reboots.

## Removed Node.js Runtime

The ISO previously installed Node.js `25.9.0` and npm `10.9.8` under
`/opt/nodejs` through the `50-install-node-runtime.hook` pacman hook and
copied them to every target system. That runtime, its hook, its
`profiledef.sh` permission entry and all `/opt/nodejs` handling were removed:

- Deleted: `airootfs/usr/local/lib/archiso/install-node-runtime.sh`
- Deleted: `airootfs/etc/pacman.d/hooks/50-install-node-runtime.hook`
- The Electron setup screen is unaffected because Electron ships its own
  bundled runtime.

## Usage / Example

Dry-run the config parsing logic from any checkout of this repo:

```bash
python3 - config.json username tontoo <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get(sys.argv[2], sys.argv[3]))
PY
```

## Cross References

- [LivePackages.md](LivePackages.md) – live packages and keyring self-heal
- [RULE.md](RULE.md) – wiki conventions

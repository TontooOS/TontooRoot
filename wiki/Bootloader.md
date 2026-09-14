# Bootloader

TontooBoot is the TontooOS boot picker built on rEFInd. It provides an
Apple Startup Manager style icon picker with TontooOS branding and
works without systemd.

## Design

The picker uses a centered icon row on a solid background. Dark mode
uses `#1d1d1d`, Light mode uses `#ececec`. The accent ring uses
TontooOS Orange `#ff6b2b`. Labels reference SF Pro Display Regular
from `BaseOS/fonts/SF-Pro/`.

| Field | Type | Description |
|---|---|---|
| `Background` | `string` | Dark background, `"#1d1d1d"` |
| `BackgroundLight` | `string` | Light background, `"#ececec"` |
| `Accent` | `string` | Selection ring, `"#ff6b2b"` |
| `IconSize` | `string` | Picker icon size, `"144"` |

## Files

Sources live in `BaseOS/bootloader/tontooboot/`. The stage script
copies them to the live ISO.

```bash
bash BaseOS/scripts/stage-tontooboot.sh
```

Staged paths:

```text
/usr/share/tontooboot/refind.conf
/usr/share/tontooboot/theme.conf
/usr/share/tontooboot/icons/
/usr/share/tontooboot/lang/en_us.json
/usr/share/tontooboot/lang/de_de.json
/usr/local/lib/baseos-setup/install-tontooboot.sh
```

## Install

Install rEFInd on an UEFI target, then apply the theme:

```bash
pacman -S refind
bash /usr/local/lib/baseos-setup/install-tontooboot.sh --esp /efi
```

The installer runs `refind-install`, copies `refind.conf` to
`/efi/EFI/refind/refind.conf` and the theme to
`/efi/EFI/refind/themes/tontooboot`. SVG icons are converted to PNG
with `rsvg-convert` when available.

Kernel options boot with `init=/usr/bin/launchpad-daemon
--services-dir /System/services` because TontooOS does not use
systemd as init.

## Languages

Picker labels are defined in `lang/`:

```json
{
  "bootloader": {
    "title": "TontooBoot",
    "tontoos": "TontooOS"
  }
}
```

Only `en_us` and `de_de` are supported. Files mirror
`./lang/en_us.json` naming.

## Usage / Example

Dry-run the stage from the repo root on Linux:

```bash
bash BaseOS/scripts/stage-tontooboot.sh
ls BaseOS/archiso/airootfs/usr/share/tontooboot
```

## Cross References

- [Installer.md](Installer.md) – target install flow, GRUB handling
- [LivePackages.md](LivePackages.md) – live packages and keyring self-heal
- [RULE.md](RULE.md) – wiki conventions

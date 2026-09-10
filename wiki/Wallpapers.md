# Wallpapers

Wallpaper packs are staged into the live ISO at `/System/User/Wallpapers/` and
used as the default desktop background by the compositor.

## Layout

Each pack is one subdirectory named in upper case. Every pack ships a
`wallpaper.fish` manifest plus its image files:

```bash
/System/User/Wallpapers/
├── BIGSUR/
├── CATALINA/
├── FLOW/
├── GOLDENGATE/
├── MOJAVE/
├── MONTEREY/
├── SEQUOIA/
├── SONOMA/
├── THAOE/
├── THAOELAKE/
├── TONTOOOS/
└── VENTURA/
```

Example manifest (`THAOELAKE/wallpaper.fish`):

```bash
name: "Tahoe Lake"
author: "Apple"
description: "Lake Tahoe on a Nice Day with Clear Water and Mountains"
images:
  light: "IMAGE.png"
  dark: "IMAGE.png"
```

## Staging

`scripts/stage-wallpapers.sh` copies every category from
`BaseOS/wallpapers/*/` into the profile overlay:

```bash
bash BaseOS/scripts/build-iso.sh
```

- Source: `BaseOS/wallpapers/<PACK>/`
- Target: `BaseOS/archiso/airootfs/System/User/Wallpapers/<PACK>/`
- The script removes the old target first, then copies each pack with `cp -a`.
- A compatibility symlink is kept at
  `/usr/share/tontoo/wallpapers` pointing to `/System/User/Wallpapers` so
  older paths keep working.

## Default Wallpaper

The compositor loads its default background from the new location unless the
`TONTOO_WALLPAPER` environment variable overrides it:

```bash
/System/User/Wallpapers/THAOELAKE/IMAGE.png
```

The legacy path `/usr/share/tontoo/wallpapers/THAOELAKE/IMAGE.png` resolves to
the same file through the compatibility symlink.

## Installer

`install-system.sh` copies the live `/System/User/Wallpapers` directory to
the target system at the same path via `install_assets_into_target`, so
installed systems keep the same layout and default as the live ISO.

## Usage / Example

List the staged packs after staging:

```bash
bash BaseOS/scripts/stage-wallpapers.sh
ls -1 BaseOS/archiso/airootfs/System/User/Wallpapers
```

Override the wallpaper for one compositor run:

```bash
TONTOO_WALLPAPER=/System/User/Wallpapers/SONOMA/IMAGE.png tontoo-compositor
```

## Cross References

- [Installer.md](Installer.md) – asset copy to the target system
- [LivePackages.md](LivePackages.md) – live packages and keyring self-heal
- [RULE.md](RULE.md) – wiki conventions

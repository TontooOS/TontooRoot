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
├── DEPTH/
├── FLOW/
├── GOLDENGATE/
├── LEGACYTIMES/
├── MOJAVE/
├── MONTEREY/
├── PRISM/
├── SEQUOIA/
├── SONOMA/
├── THAOE/
├── THAOELAKE/
├── TONTOOOS/
├── VENTURA/
└── VORTEX/
```

The `DEPTH`, `PRISM` and `VORTEX` packs are generated 3D glass-ribbon
wallpapers (5120x2880 `LIGHT.png` + `DARK.png`). The generator script is
kept at `temp/generate_3d_wallpapers.py` in the TontooOS checkout and is
never deleted, so variants stay reproducible:

```bash
python3 temp/generate_3d_wallpapers.py --packs VORTEX,PRISM,DEPTH
```

The `LEGACYTIMES` pack is retro 2005-2010 nostalgia in modern render
quality (5120x2880 `LIGHT.png` + `DARK.png`): a Bliss-hill homage with
Aero gloss bubbles by day, a Vista-aurora night with moon, stars and a
sodium-lamp horizon glow. Its generator is kept at
`temp/generate_legacy_times.py` in the TontooOS checkout and is never
deleted:

```bash
python3 temp/generate_legacy_times.py
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
  older paths keep working. The link target is relative
  (`../../../System/User/Wallpapers`): absolute targets escape the airootfs
  workdir when `mkarchiso` resolves paths and abort the build with
  `Outside of valid path`.

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

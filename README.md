# BaseOS

Arch Linux live ISO profile for the first bootable base layer.

Documentation: [wiki/MAIN.md](wiki/MAIN.md)

## Layout

```text
BaseOS/
├── archiso/              # mkarchiso profile
├── scripts/              # build helpers
└── out/                  # generated ISO output, ignored by git
```

## Fonts

The system uses SF Pro as the default font family:

- `SF Pro` (variable TTF)
- `SF Pro Display` (individual OTF weights)
- `SF Pro Text` (individual OTF weights)
- `SF Pro Rounded` (individual OTF weights)

SF Pro fonts are bundled in the ISO at `/usr/share/fonts/OTF/` and `/usr/share/fonts/TTF/`. The fontconfig fallback chain continues with Inter, Noto Sans, and DejaVu Sans.

Font Awesome is installed globally through the Arch package `otf-font-awesome`, so applications can use the installed Font Awesome font family.

## Cursors

The MacTahoe cursor themes from `ai_temp_filees/MacTahoe-icon-theme/cursors` are built and installed system-wide:

```text
/usr/share/icons/MacTahoe-cursors
/usr/share/icons/MacTahoe-dark-cursors
```

`MacTahoe-cursors` is configured as the default cursor theme for Xcursor, GTK, LightDM, and the setup session.

The setup session also starts a transparent global `Shake to Find Cursor` overlay. Fast back-and-forth mouse movement temporarily shows a large cursor above the current screen so it is easier to find on large displays. The same helper is also registered through XDG autostart for later desktop sessions.

## Startup Icon

The default icon from `icons/tontoo_default.png` is installed into the live system as:

```text
/usr/share/pixmaps/tontoo-default.png
```

It is used for the Electron setup window, the short setup startup splash, and the `liveuser` account icon.

The boot path also uses a black Plymouth splash theme with a small centered Octopus icon and a thin bottom progress bar. Kernel/systemd boot output is suppressed with quiet boot parameters, and `systemd-firstboot` is masked so the live ISO does not stop on an interactive timezone prompt before the setup screen.

## Sounds

The TontooOS sound theme is vendored from:

```text
https://github.com/pearOS-archlinux/pearos-sounds
```

It is installed into the live system at:

```text
/usr/share/sounds/tontoosounds
```

The copied theme includes its upstream `LICENSE` file. GTK is configured to use the `tontoosounds` sound theme through `libcanberra`, and the setup wizard plays one short forward-navigation sound when `Next` succeeds.

## Build

From the repository root, use the helper so staged packages and apps are copied before `mkarchiso` runs:

```bash
bash BaseOS/scripts/build-iso.sh
```

With `--github-actions`, component sources are cloned from
`github.com/${GITHUB_ORG}` (default `TontooOS`) next to the checkout instead
of using local sibling directories, then the same build runs:

```bash
bash BaseOS/scripts/build-iso.sh --github-actions
```

Cloned repos: `Compositor`, `FishPerms`, `LaunchPad`, `LaunchCTL`,
`FishRunner`, `MenuBar` (as `Menubar`), `TBuild`, `LaunchPadLib` and all
`TontooLibs` frameworks. Cursor and GTK theme sources are vendored under
`BaseOS/vendor/`, fonts and wallpapers live in `BaseOS/fonts/` and
`BaseOS/wallpapers/`. `shell_ui/` and `TontooUI/` sources are optional and
skipped when absent.

## License

TCL v26.1, see [LICENSE.md](LICENSE.md).

Third-party components (MacTahoe theme and cursors, TontooOS sound theme,
SF Pro fonts, wallpapers) remain under their respective licenses.
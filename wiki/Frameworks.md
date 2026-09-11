# Frameworks

System libraries are built from the local `TontooLibs` sources and staged as
compiled bundles plus their runtime resources under `/Library/System`
(`stage-frameworks.sh`, run by `build-iso.sh`).

## Layout on the Device

| Path | Content |
|---|---|
| `/Library/System/<name>.library` | Compiled `cdylib` (e.g. `coreicon.library`) |
| `/Library/System/<name>.resources/` | Sidecar resources: `assets/`, `lang/`, `fonts/`, ... |
| `/Library/System/<name>/` | Staged crate sources (build-time path deps) |

Example: `coreicon.library` plus `coreicon.resources/assets/icons/` (SF Symbols),
`coreicon.resources/assets/TontooOS/` (branding) and
`coreicon.resources/assets/TontooOS/OSVersionAssets/<version>/`.

> **Note:** Libraries that ship no runtime resources (e.g. `fishfile`,
> `coredata`, `foundation`, `uikitdynamics`) get no `.resources` folder.

## Staged Frameworks

16 frameworks, in dependency order (`fishfile` before `coredata`):

| System name | Source dir | Notes |
|---|---|---|
| `fishfile` | `FishFile` | No resources |
| `coredata` | `CoreData` | Depends on `fishfile`; no resources |
| `coresettings` | `CoreSettings` | `lang/` staged |
| `corewindows` | `CoreWindows` | `lang/` staged |
| `accessibility` | `Accessibility` | `lang/` staged |
| `corelocation` | `CoreLocation` | `lang/` staged |
| `coreicon` | `CoreIcon` | `assets/icons/`, `assets/TontooOS/` staged (~336M SF Symbols) |
| `foundation` | `Foundation` | No resources |
| `networkkit` | `NetworkKit` | `lang/` staged |
| `uikitdynamics` | `UIKitDynamics` | No resources |
| `uikit` | `UIKit` | `assets/` (traffic-light icons) staged |
| `webkit` | `WebKit` | `lang/` staged |
| `tontooui` | `TontooUI` | `lang/` staged |
| `mapskit` | `MapsKit` | `lang/` staged |
| `weatherkit` | `WeatherKit` | `lang/` staged |
| `launchpad` | `LaunchPad` | `lang/` staged; cargo lib name is `launchpad_lib` |

Most libraries embed their `lang/` files at compile time via `include_str!`;
`accessibility` loads them at runtime (see below). Staging the files anyway
keeps overrides and future runtime loaders working.

## Resolver Contract

Every library resolves its resources at runtime with the same priority:

1. Environment override (e.g. `COREICON_ASSETS_DIR`, `UIKIT_ASSETS_DIR`,
   `ACCESSIBILITY_LANG_DIR`)
2. LiveOS sidecar: `/Library/System/<name>.resources/...`
3. Staged sources: `/Library/System/<name>/...`
4. Relative crate dir (`assets/...`, `./lang`; dev / `cargo run`)

Callers never hardcode a path; they use the resolver (`resolve_icon_path`,
`resolve_octopus_dir`, `resolve_os_version_base`, `resolve_lang_dir`,
UIKit `asset_path`). The relative default is returned when nothing exists so
error messages stay familiar.

## Build Details

```bash
bash BaseOS/scripts/build-iso.sh
```

Behavior:

- Each framework is built with `cargo build --release`; when no `cdylib` is
  produced, a `crate-type = ["cdylib", "rlib"]` section is appended and the
  build is retried (staged copy kept in sync).
- Entries use the form `system-name:RepoDir[:so-name]`; `so-name` defaults to
  the system name (`-` becomes `_`) and is only needed when the cargo lib
  name differs (e.g. `launchpad:LaunchPad:launchpad_lib`).
- Resource staging (`assets`, `lang`, `Resources`, `resources`, `fonts`,
  `images`, `icons`, `data`) is best-effort and never fails the build.
- In `--github-actions` mode the sources are cloned from the `TontooOS` org
  first (`CoreData`, `CoreSettings`, `CoreWindows`, `FishFile` included;
  the client lib comes from repo `LaunchPadLib`).

## Cross References

- [MAIN.md](MAIN.md) – index and changelog
- [LivePackages.md](LivePackages.md) – live ISO packages

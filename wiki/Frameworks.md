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

> **Note:** Libraries that ship no runtime resources (e.g. `foundation`,
> `fishfile`, `archivekit`, `coredata`) get no `.resources` folder.

## Staged Frameworks

22 frameworks, in dependency order (every path dependency is staged before its
dependents, so each build resolves its siblings from `/Library/System/<name>`):

| # | System name | Source dir | Notes |
|---|---|---|---|
| 1 | `foundation` | `Foundation` | No resources; base of nearly every framework |
| 2 | `coretext` | `CoreText` | `lang/` staged |
| 3 | `coreimage` | `CoreImage` | `lang/` staged |
| 4 | `fishfile` | `FishFile` | No resources |
| 5 | `archivekit` | `ArchiveKit` | No resources |
| 6 | `sqlkit` | `SQLKit` | `lang/` staged |
| 7 | `coredata` | `CoreData` | Depends on `fishfile` + `sqlkit`; no resources |
| 8 | `coresettings` | `CoreSettings` | `lang/` staged |
| 9 | `networkkit` | `NetworkKit` | `lang/` staged |
| 10 | `audiokit` | `AudioKit` | `lang/` staged |
| 11 | `corelocation` | `CoreLocation` | `lang/` staged |
| 12 | `coreicon` | `CoreIcon` | `assets/icons/`, `assets/TontooOS/` staged (~336M SF Symbols) |
| 13 | `corewindows` | `CoreWindows` | `lang/` staged |
| 14 | `accessibility` | `Accessibility` | `lang/` staged |
| 15 | `mediakit` | `MediaKit` | `lang/` staged |
| 16 | `tontooui` | `TontooUI` | `assets/`, `lang/` staged |
| 17 | `webkit` | `WebKit` | `lang/` staged |
| 18 | `mapskit` | `MapsKit` | `lang/` staged |
| 19 | `weatherkit` | `WeatherKit` | `lang/` staged |
| 20 | `pdfkit` | `PDFKit` | `lang/` staged |
| 21 | `documentkit` | `DocumentKit` | `lang/` staged |
| 22 | `launchpad` | `LaunchPad` | `lang/` staged; cargo lib name is `launchpad_lib` |

The list covers every framework crate in `TontooLibs`, so the SDK can
`dlopen` any of them from `/Library/System` at runtime. The SDK binding crate
itself (`TontooLibs/SDK`) is not a framework: it is `rlib`-only and is
referenced through `/Library/System/sdk`, not staged as a `.library`.

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
- The release artifacts are **not** assumed to land in `<repo>/target`.
  `resolve_target_dir` asks cargo (`CARGO_TARGET_DIR`, then
  `cargo metadata`) where they really are, because a `build.target-dir`
  entry in `~/.cargo/config.toml` redirects them (the WSL toolchain shares one
  cache dir for every crate). Without this lookup no `.library` is found and
  the ISO silently ships none.
- Entries use the form `system-name:RepoDir[:so-name]`; `so-name` defaults to
  the system name (`-` becomes `_`) and is only needed when the cargo lib
  name differs (e.g. `launchpad:LaunchPad:launchpad_lib`).
- Resource staging (`assets`, `lang`, `Resources`, `resources`, `fonts`,
  `images`, `icons`, `data`) is best-effort and never fails the build.
- In `--github-actions` mode the sources are cloned from the `TontooOS` org
  first, all 22 framework repos in the same order as the table above (the
  `LaunchPad` client lib comes from repo `LaunchPadLib`).

## Cross References

- [MAIN.md](MAIN.md) – index and changelog
- [LivePackages.md](LivePackages.md) – live ISO packages

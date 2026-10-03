# BaseOS – Wiki

BaseOS is the minimal Arch Linux live ISO profile for TontooOS. It proves the
boot and desktop path before branded layers are added.

- Repository: https://github.com/TontooOS/base-os
- License: TCL v27.0
- Version: 0.1.0

## Feature Index

| Feature | File | Description |
|---|---|---|
| Main index | [MAIN.md](MAIN.md) | This page |
| Rules | [RULE.md](RULE.md) | Development and usage rules |
| LivePackages | [LivePackages.md](LivePackages.md) | Live ISO packages and pacman keyring self-heal |
| ServiceHardening | [ServiceHardening.md](ServiceHardening.md) | Per service sandbox policy for `/System/services/*.service` |
| Frameworks | [Frameworks.md](Frameworks.md) | System libraries: `.library` bundles plus `.resources` sidecars under `/Library/System` |
| Installer | [Installer.md](Installer.md) | Destructive Arch installer, Python config parsing |
| Bootloader | [Bootloader.md](Bootloader.md) | TontooBoot rEFInd picker, Apple style, Dark #1d1d1d |
| Wallpapers | [Wallpapers.md](Wallpapers.md) | Wallpaper packs at `/System/User/Wallpapers` and staging |

## Quick Start

Build the ISO on Arch Linux with `archiso` installed:

```bash
bash BaseOS/scripts/build-iso.sh
```

Boot the output ISO in QEMU and log in over SSH as `liveuser`:

```bash
ssh -p 2222 liveuser@127.0.0.1
```

See [LivePackages.md](LivePackages.md) for details.

## Changelog

- 2026-10-03: `stage-frameworks.sh` now builds **every** framework in
  `TontooLibs` (16 -> 22), so the ISO ships a `.library` for each one and the
  SDK can `dlopen` all of them from `/Library/System`. Added `coretext`,
  `coreimage`, `archivekit`, `sqlkit`, `audiokit`, `mediakit`, `pdfkit` and
  `documentkit`; dropped `uikit` and `uikitdynamics`, which no longer exist in
  `TontooLibs`. The list is a valid topological order (every path dependency
  is staged before its dependents, e.g. `coretext` before `coreimage`,
  `archivekit` before `coreicon`, `mediakit` before `tontooui`).
  `build-iso.sh` clones the same 22 repos in `--github-actions` mode, so CI
  builds them too. Also fixed a bug that made the stage silently produce
  nothing on this machine: the release artifacts are not in `<repo>/target`
  when `~/.cargo/config.toml` sets `build.target-dir` (the WSL toolchain
  shares one cache dir for all crates), so the hardcoded
  `target/release/lib<name>.so` lookup never matched. `resolve_target_dir` now
  asks cargo (`CARGO_TARGET_DIR`, then `cargo metadata`) where the artifacts
  really are. See [Frameworks.md](Frameworks.md).
- 2026-10-02: Service sandboxing for all 17 files in
  `archiso/airootfs/System/services/`. LaunchPad replaces systemd, so every
  root service was running unconfined: no `no_new_privs`, no mount namespace,
  no capability bounding set and no cgroups. Each service now declares
  `no_new_privs`, `private_tmp`, `protect_system: full`, `read_only_paths`
  where it reads `/System` or `/Applications`, and `memory_max` plus
  `tasks_max`. `pipewire`, `wireplumber` and `pipewire-pulse` moved from
  `user: root` to `user: session`, so the whole audio stack no longer runs as
  root, and `pipewire` gained a `live-setup` dependency because the live ISO
  creates the account in that service. `sshd` is deliberately left
  unconfined, and `networkmanager` and `seatd` deliberately carry no
  `capabilities` allowlist, all three documented in
  [ServiceHardening.md](ServiceHardening.md). No service uses `device_allow`
  yet: the cgroup v2 device filter needs a kernel verifier check that cannot
  run under WSL2.
- 2026-09-30: Added `LEGACYTIMES` wallpaper pack
  (`BaseOS/wallpapers/LEGACYTIMES/LIGHT.png` + `DARK.png`, 5120x2880):
  retro 2005-2010 nostalgia, Bliss hill with Aero gloss by day and
  starry night with a blurry orange sodium street lamp. Generator kept at
  `temp/generate_legacy_times.py`. See [Wallpapers.md](Wallpapers.md).

- 2026-09-30: Added `DEPTH`, `PRISM` and `VORTEX` wallpaper packs
  (`BaseOS/wallpapers/<PACK>/LIGHT.png` + `DARK.png`, 5120x2880): generated
  3D glass-ribbon flow waves with Light/Dark variants. Generator kept at
  `temp/generate_3d_wallpapers.py`. See [Wallpapers.md](Wallpapers.md).

- 2026-09-29: Window corner radius is `17px` in the `TontooOS-Dark` and
  `TontooOS-Light` GTK themes (`window.csd`/`decoration` plus attached
  headerbar top corners in all `gtk-3.0`/`gtk-4.0` `gtk.css`/`gtk-dark.css`
  files), matching TontooUI `WINDOW_CORNER_RADIUS`.

- 2026-09-28: Pre-rendered the TontooBoot selection rings
  (`selection-big.png` 144x144, `selection-small.png` 48x48, orange
  `#ff6b2b`) and committed them in `BaseOS/bootloader/tontooboot/`.
  `install-tontooboot.sh` copies them instead of generating PNGs with
  Python (both Python blocks removed, including the dead light-mode
  placeholder), `stage-tontooboot.sh` stages them to
  `/usr/share/tontooboot`, and `install-system.sh` now also copies the
  rings into the target ESP theme (previously missing there).
- 2026-09-28: Removed `rust`, `chromium`, `xorg-xcursorgen`, `qt5ct`,
  `qt6ct`, all VM guest agents (`open-vm-tools`, `qemu-guest-agent`,
  `virtualbox-guest-utils`, `spice-vdagent`), `python-pip`, extra
  filesystem tools (`f2fs-tools`, `xfsprogs`, `exfatprogs`, `ntfs-3g`,
  `mtools`) and `git` from the live (`packages.x86_64`) and, where
  present, target (`install-system.sh`) package lists. No browser ships
  by default; install one on demand via `pacman`.
- 2026-09-28: Removed fallback terminals `foot`, `xterm` and `alacritty`
  from the live (`packages.x86_64`) package list plus the stale
  `/etc/foot/foot.ini` config and its installer copy. Tontoo Terminal.app
  remains the only terminal.
- 2026-09-28: Removed legacy Electron setup kiosk
  (`airootfs/usr/share/baseos-setup/`,
  `airootfs/usr/local/bin/baseos-setup-session`) and dropped `electron` and
  `pavucontrol` from the live (`packages.x86_64`) and target
  (`install-system.sh`) package lists. The shell installer backend is kept.
- 2026-09-28: `stage-launchpad.sh` builds strictly from the sibling
  component repos (`../TontooServices/LaunchPad` daemon,
  `../TontooProgramms/LaunchCTL` CLI, `../TontooLibs/LaunchPad` lang);
  the legacy `TontooLibs/LaunchPad` daemon fallback is removed. In
  `--github-actions` mode the CI-cloned in-repo paths are used.
- 2026-09-24: Fixed compositor stage abort on a dangling
  `tontoo-compositor -> wayfire` symlink in the staged airootfs:
  `stage-compositor.sh` removes any existing file or symlink at
  `/usr/bin/tontoo-compositor` before copying the freshly built Smithay
  binary, so plain `cp -f` no longer refuses to write through the stale
  Wayfire leftover.
- 2026-09-24: Reverted the ISO compositor stage from Wayfire back to the
  Smithay `tontoo-compositor` (`stage-compositor.sh`): cargo
  `--release --no-default-features --features udev` stages
  `/usr/bin/tontoo-compositor` again; meson/ninja, bundled wlroots and
  `wayfire.ini` staging removed. `start-compositor.sh` execs
  `tontoo-compositor --udev`; `tontoo.desktop` points at the Smithay
  binary; `wayfire.desktop`, the skel `wayfire.ini` and staged
  `/usr/bin/wayfire` + `/usr/share/wayfire` leftovers deleted;
  `profiledef.sh`, `customize_airootfs.sh`, `packages.x86_64` and
  `.gitignore` no longer reference Wayfire paths.
- 2026-09-21: Fixed compositor missing on LiveOS: `stage-compositor.sh`
  copied only `build/src/wayfire` into the ISO, so the live system missed
  the bundled shared libs (`libwlroots-0.20.so`, `libwf-config.so.1`,
  `libwf-utils.so.0`, `libyyjson.so.0`) and all `/usr/lib/wayfire`
  plugins (`ldd /usr/bin/wayfire` showed `not found`,
  `start-compositor.sh` restart-looped, no `WAYLAND_DISPLAY`). The stage
  now runs `DESTDIR=airootfs ninja install` (binary + libs + plugins +
  metadata) with a binary-only fallback, fixes staged `.so` modes to
  `0755`, and `.gitignore` covers the new staged paths
  (`usr/bin/wayfire`, `usr/lib/libwlroots*`, `libwf-*`, `libyyjson*`,
  `usr/lib/wayfire/`, `usr/share/wayfire/`). See the compositor
  `Building.md` Stage for ISO section.
- 2026-09-17: Fixed `theme` service crash `HOME: unbound variable` on the
  live ISO: `/usr/local/bin/tontoo-theme-apply` used `${HOME}` under
  `set -u`, but LaunchPad sets `HOME` from `/etc/passwd` only when `user:`
  resolves — `theme` started before `live-setup` created `liveuser`, so
  `HOME` was empty and the script exited `1`. The script now resolves
  `HOME` best effort (`getent passwd liveuser`, fallback `/root`) and uses
  `HOME_DIR` for all paths, so it always exits `0`. `theme.service` gained
  a `live-setup` dependency (`dbus`, `live-setup`) so the user exists
  before the themed boot path runs.
- 2026-09-15: Fixed `theme` service stuck at `restarting` on the live
  ISO: `/usr/local/bin/tontoo-theme-apply` shipped without the exec
  bit, so LaunchPad spawn failed and the tick loop retried with
  backoff forever (spawn errors ignore `restart: false`; only clean
  child exits honor it). `profiledef.sh` gained the `0:0:755`
  `file_permissions` entry (`customize_airootfs.sh` chmod alone is
  clobbered by mkarchiso). Live fix without rebuild: `sudo chmod 0755`
  the script, the service runs once and goes to `stopped`.
- 2026-09-14: Replaced GRUB with TontooBoot on installed systems
  (`Installer.md`, `install-system.sh`): UEFI systems use rEFInd,
  BIOS systems fall back to GRUB. GPT layout with BIOSBOOT + ESP +
  ROOT, `refind` + `grub` + `librsvg` target packages,
  `install_tontooboot_into_target` with real root UUID and
  `refind_linux.conf` fallback. Live ISO now patched post-build:
  GRUB in efiboot.img replaced with rEFInd + TontooBoot theme,
  BIOS still boots via syslinux.
- 2026-09-14: Added TontooBoot (`Bootloader.md`): rEFInd based Apple style
  picker, Dark `#1d1d1d` default, SF Pro reference, `en_us` + `de_de`
  labels, `stage-tontooboot.sh` staging to `/usr/share/tontooboot`,
  `refind` live package, installer at
  `/usr/local/lib/baseos-setup/install-tontooboot.sh`.
- 2026-09-11: Fixed `mkarchiso` abort `Outside of valid path` on
  `/Applications/SystemOverview.app`: the `/Applications` links
  (`stage-systemoverview.sh`, `stage-systemsettings.sh`) and the wallpaper
  compatibility link (`stage-wallpapers.sh`) used absolute `/System/...`
  targets, which escape the airootfs workdir when `mkarchiso` resolves
  `file_permissions` entries. All three links are relative now
  (`../System/...`, `../../../System/User/Wallpapers`); `profiledef.sh`
  permissions are unchanged.
- 2026-09-11: Stage SystemSettings into the ISO
  (`stage-systemsettings.sh`): TBuild bundle built from
  `TontooMicroApps/SystemSettings` and extracted as a folder at
  `/System/Applications/SystemSettings.app` (on demand via tapp, no
  service), system-wide link at `/Applications/SystemSettings.app`
  (top-level system path, not per-user), language fallback at
  `/usr/share/systemsettings/lang`, installer copy, profiledef
  permissions and gitignore updated.
- 2026-09-11: Stage SettingsDaemon into the ISO
  (`stage-settingsdaemon.sh`): Rust release binary assembled as a
  TBuild-style bundle at `/System/Daemons/Settings.app`
  (`App/settings-daemon`, `Info.tontoo` versioned from the crate),
  started at boot via the `SettingsDaemon` LaunchPad service
  (`System/services/SettingsDaemon.service` ->
  `start-settingsdaemon.sh` -> `tapp`, root, restart), FishPerms trust
  via `/System/Daemons/**`, installer copy, profiledef permissions and
  gitignore updated.
- 2026-09-11: SystemOverview link moved to the system root
  (`stage-systemoverview.sh`): the app is now linked system-wide as
  `/Applications/SystemOverview.app` instead of per-user via
  `~/Applications/SystemOverview.app` (`/etc/skel`); the legacy skel link
  is removed at stage time, `profiledef.sh` gained the new path, the
  installer (`install-system.sh`) creates the system link on target and
  cleans the legacy user link on upgrades. The Menubar "About This Machine"
  entry launches the system link (fallbacks: bundle directly, legacy
  user link).
- 2026-09-11: Stage framework resources and all libraries
  (`stage-frameworks.sh`): every framework now stages its runtime resources
  (`assets/`, `lang/`, ...) as a `/Library/System/<name>.resources/` sidecar
  next to `<name>.library` (fixes missing SF Symbols / icons on LiveOS);
  added the missing `fishfile`, `coredata`, `coresettings`, `corewindows`
  and `launchpad` frameworks (16 total, `so-name` override for
  `launchpad_lib`); libraries resolve resources at runtime via the
  sidecar-first contract. See [Frameworks.md](Frameworks.md).
- 2026-09-10: Stage Dock into the ISO (`stage-dock.sh`): TBuild bundle
  built from `TontooProgramms/Dock` (`tontoo.proj`, `com.tontoo.dock`)
  and extracted as a folder at `/System/Applications/Dock.app`, started
  at boot via the   `dock` LaunchPad service
  (`System/services/dock.service` -> `start-dock.sh` -> `tapp`),
  language files at `/usr/share/tontoo/dock/lang`, installer copy,
  profiledef permissions and gitignore updated. Same pattern as
  `Menubar.app`, except the starter pins `GDK_BACKEND=x11`: the dock
  has no layer-shell code and positions itself via X11 moves only.
- 2026-09-10: Stage wallpaper packs to `/System/User/Wallpapers/`
  (`stage-wallpapers.sh`): all packs copied to the new canonical path,
  compositor default points there, legacy `/usr/share/tontoo/wallpapers`
  kept as a compatibility symlink, installer copy, profiledef permissions
  and gitignore updated. See [Wallpapers.md](Wallpapers.md).
- 2026-09-10: Stage Weather into the ISO (`stage-weather.sh`): TBuild bundle
  extracted as a folder at `/Applications/Weather.app` (top-level path, no
  symlink, no service), language fallback at `/usr/share/weather/lang`,
  installer copy, profiledef permissions and FishPerms trust via
  `/Applications/**`.
- 2026-09-10: Stage AboutThisApp into the ISO (`stage-aboutthisapp.sh`):
  TBuild bundle extracted as a folder at `/System/Applications/AboutThisApp.app`
  (no symlink, no service), installer copy, profiledef permissions and
  FishPerms trust via `/System/Applications/**`.
- 2026-09-08: Stage SystemOverview into the ISO (`stage-systemoverview.sh`):
  extracted folder at `/System/Applications/systemoverview.app`,
  `~/Applications/SystemOverview.app` skel link, installer copy,
  profiledef permissions and FishPerms trust via `/System/Applications/**`.
- 2026-09-07: Clone the LaunchPad daemon from the `master` branch
  (`main` holds the client lib); `clone_github_repo` supports branches.
- 2026-09-07: Hardened the build: every stage is best-effort now (failing
  clone, missing binary or failed framework warns and continues);
  `build-iso.sh` prints a failed-stage summary after `mkarchiso`.
  `stage-launchpad.sh` copies binaries only when built (fixes `cp` abort
  before the legacy fallback). Workflow installs `sassc`, `perl`, `gawk`
  and `gtk4`.
- 2026-09-07: Added `.github/workflows/build-iso.yml`: manual workflow with
  a `version` input (e.g. `27.0.0`); builds the ISO in a privileged Arch
  container via `build-iso.sh --github-actions`, splits assets over 1800M
  and publishes a GitHub release with SHA256 checksums.
- 2026-09-07: Added `--github-actions` to `scripts/build-iso.sh` (forwarded
  to all `stage-*.sh` helpers): clones component repos from the TontooOS
  GitHub org next to the checkout instead of using local sibling dirs.
  Vendored MacTahoe cursor and GTK theme sources into `BaseOS/vendor/`;
  `stage-cursors.sh`, `stage-mactahoe-theme.sh` and the CRLF fix in
  `build-iso.sh` now use the in-repo copies.
- 2026-09-07: Repository made GitHub-ready: new `.gitignore` for staged
  airootfs artifacts (fonts, wallpapers, binaries, frameworks, Menubar app,
  SSH host keys) and build outputs; added `LICENSE.md` (TCL v27.0);
  removed committed SSH host keys and staged font/wallpaper duplicates
  (regenerated by `scripts/build-iso.sh`).
- 2026-09-07: Added `chromium` to the live ISO and the installer target
  packages; live boot now self-heals the pacman keyring; removed the
  Node.js/npm runtime from the ISO (installer uses `python3`).
- 2026-08-13: Initial BaseOS live profile with Electron setup kiosk.

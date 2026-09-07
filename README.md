# BaseOS

Arch Linux live ISO profile for the first bootable base layer.

Documentation: [wiki/MAIN.md](wiki/MAIN.md)

This stage is intentionally neutral:

- no product branding
- no custom theme
- no shell applications

The goal is to keep the platform generic while proving the boot and desktop path. Branded layers and custom shell applications should be added only after this profile can build and boot reliably.

## Layout

```text
BaseOS/
├── archiso/              # mkarchiso profile
├── scripts/              # build helpers
└── out/                  # generated ISO output, ignored by git
```

## First Setup

The live ISO starts a neutral setup kiosk:

- LightDM display manager with autologin
- Electron-based setup screen
- English and German language choices
- Keyboard layout and timezone choices
- LAN/WLAN selection screen
- First-user draft screen with username, name, computer name, password confirmation, 10 icons, and 10 colors
- Light/dark setup theme switch
- SSH access draft screen with enable toggle, port, and root-login option
- Real harddrive selection screen using `lsblk`, with device name, size, and volumes
- Install screen with logo, progress, live log, and final warning
- Destructive Arch installer for the selected harddrive

The live user is `liveuser` with an empty password. LightDM logs into the `baseos-setup` session automatically.

The installer entry point is:

```text
/usr/local/lib/baseos-setup/install-system.sh
```

The setup screen starts it through Electron IPC only after the final `Install` confirmation. Before erasing the disk, it verifies that pacman has package mirrors and can refresh the Arch keyring. It then wipes the selected disk, creates a GPT layout for UEFI and legacy BIOS, installs Arch Linux with Xfce and LightDM, creates the first user, applies language/keyboard/timezone/SSH settings, installs GRUB, and enables a first-boot finalization service. The machine reboots from the live installer, performs one first-boot finalization reboot, and then autologins to the Xfce desktop.

## Live Packages

- `chromium` is part of the live ISO (`archiso/packages.x86_64`) and is also
  installed to the target system by the installer, so `chromium` works out of
  the box on live and installed systems.
- Every live boot runs `enable-live-desktop.sh` (via the `live-setup`
  LaunchPad service), which recreates `/etc/pacman.d/mirrorlist` when missing
  and initializes/populates the pacman keyring (`pacman-key --init`,
  `pacman-key --populate archlinux`). `pacman -Sy <pkg>` therefore works on a
  fresh live boot without manual keyring repair.

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

## App Runner

The `tapp` app runner from the FishRunner repository launches `.app` bundles
built with TBuild. It is staged by `BaseOS/scripts/stage-fishrunner.sh` into:

```text
/usr/bin/tapp
/usr/share/tapp/lang
```

At boot the `tapp-binfmt` LaunchPad registers a `binfmt_misc` handler, so any
executable `.app` file (for example a freshly downloaded bundle) is dispatched
to `tapp` when executed directly. Apps installed by a `.tinstaller` live as
directory bundles and are started via `tapp <path>.app`; opening any `.app`
from a file manager is covered by the MIME type `application/x-tontoo-app`,
which maps to the runner desktop entry.

## System Menubar

The top menu bar is not rendered by the compositor. It is the external
`Menubar.app` system app, built with TBuild from `TontooProgramms/Menubar`
(`bundle_id` `com.tontoo.menubar`) and staged by
`BaseOS/scripts/stage-menubar.sh` into:

```text
/System/Applications/Menubar.app   (extracted bundle: App/menubar, Info.tontoo, Resources/)
/usr/share/tontoo/menubar/lang     (en_us.json, de_de.json)
/usr/local/bin/start-menubar.sh    (starter: waits for the Wayland socket, then tapp)
```

At boot the `menubar` LaunchPad service (`Library/System/Launchpads/menubar.service`,
type `sys`, user `liveuser`, `depends_on` compositor + live-setup, `restart: true`)
starts it via `start-menubar.sh`. On installed systems the installer writes a
per-user variant (`user: <username>`). The compositor only reserves the 30 px
top strut; windows are placed below it. The bundle is sealed by FishPerms
(`protected.conf`: `/System/**`) and trusted (`trusted.conf`:
`/System/Applications/Menubar.app/**`).

## System Protection

FishPerms protects system binaries, libraries and fonts like macOS SIP:
`/usr/bin/{launchpad-daemon, launchctl, tapp, fishperms-*, tontoo-*}`,
`/usr/local/bin/*`, `/Library/System/**` and `/usr/share/fonts/{OTF,TTF}/**`
are sealed with fs-verity and the immutable bit - even root receives `EPERM`.
The policy lives at `/Library/Preferences/FishPerms/protected.conf`; digests
are verified against a manifest on every boot by the `FishPerms` LaunchPad.
There is no unlock command: legitimate changes flow through the OS updater or
a reinstall from the live ISO.
At boot the `FishPerms` LaunchPad re-applies those locks, verifies digests
against its manifest and then runs the app access gate: fanotify permission
events block `open()` inside `/Users` for `.app` processes until the user
answers a confirmation popup (`fishperms-prompt`); Allow/Don't Allow decisions
persist in `/Library/Preferences/FishPerms/access.grants.json`. The installer
enables the ext4 `verity` feature on the root partition automatically
(`tune2fs -O verity`).

On top of that, every user session runs behind **FishBox** (`fishbox`, a
seccomp-notify supervisor started by the compositor service): any process in
the session - terminal binaries included - gets frozen with a popup
(Ja / Nein / Immer) the first time it touches `/Users`. System components are
exempt via `/Library/Preferences/FishPerms/trusted.conf`; there is no escape
hatch. `tapp` routes all `.app` launches through fishbox automatically.

## Developer Runtime

The live ISO ships no system-wide Node.js/npm runtime. The installer
(`install-system.sh`) parses its JSON configuration with `python3`, which is
already part of the ISO packages. The Electron setup screen brings its own
bundled runtime, so no `/opt/nodejs` or `/usr/local/bin/node` links exist on
the live system or on installed targets.

Build hosts still need `nodejs`/`npm` to stage the `liquid-glass` package
(see `Build Requirements` below); that tooling never enters the ISO.

During the ISO build, `BaseOS/scripts/stage-liquid-glass.sh` stages `LiquidLibarie` as a static package:

```text
/usr/local/lib/node_modules/@tontoo-os/liquid-glass
```

The setup screen loads the staged package directly and uses `lg-button` for the wizard action buttons. The installer copies the staged files to the target system; no runtime linking is performed.

`BaseOS/scripts/stage-tontoo-terminal.sh` builds and stages the terminal app from:

```text
apps/terminal
```

into:

```text
/usr/share/tontoo-terminal
```



## Build Requirements

Build on Arch Linux or an Arch-based Linux environment with `archiso` installed.

Recommended host packages:

```bash
sudo pacman -S --needed archiso qemu edk2-ovmf nodejs npm base-devel python
```

The helper must use Linux `node`/`npm` from the Arch build environment. Windows Node.js/npm exposed through `/mnt/c` is not supported for staging apps with native modules.

## Build

From the repository root, use the helper so staged packages and apps are copied before `mkarchiso` runs:

```bash
bash BaseOS/scripts/build-iso.sh
```

The helper uses `/tmp/baseos-archiso-work` by default. Override it with:

```bash
ARCHISO_WORKDIR=/tmp/another-workdir bash BaseOS/scripts/build-iso.sh
```

If you run `mkarchiso` directly, run the staging scripts first.

## Test

BIOS boot:

```bash
run_archiso -i BaseOS/out/*.iso
```

UEFI boot:

```bash
run_archiso -u -i BaseOS/out/*.iso
```

After boot, LightDM should autologin as `liveuser` and show the setup screen. If the login screen appears, select `liveuser`, leave the password field empty, and press `Enter`.

If the setup session fails, switch to a TTY with `Ctrl+Alt+F2`, log in as `root` with an empty password, and run:

```bash
desktop-debug
```

NetworkManager should be active in the live system:

```bash
systemctl status NetworkManager
pacman -Sy
```

## Staged Artifacts

`scripts/build-iso.sh` regenerates everything under `archiso/airootfs/` that
is built or copied from other sources (SF Pro fonts from `BaseOS/fonts`,
wallpapers from `BaseOS/wallpapers`, cursors, GTK themes, service binaries,
frameworks, the Menubar app bundle, language files, SSH host keys). Those
generated paths are listed in `.gitignore` and are not committed. A fresh
clone only needs the sources plus `bash BaseOS/scripts/build-iso.sh`.

## License

TCL v26.1, see [LICENSE.md](LICENSE.md).

Third-party components (MacTahoe theme and cursors, TontooOS sound theme,
SF Pro fonts, wallpapers) remain under their respective licenses.

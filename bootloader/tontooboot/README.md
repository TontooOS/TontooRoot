# TontooBoot

TontooBoot is the TontooOS boot picker built on rEFInd. Apple Startup
Manager style icon picker with TontooOS branding.

- Base: rEFInd (UEFI only, no systemd dependency)
- Dark default background `#1d1d1d`, Light `#ececec`
- System font reference: SF Pro Display Regular
  (`BaseOS/fonts/SF-Pro/SF-Pro-Display-Regular.otf`)
- Languages: `lang/en_us.json` and `lang/de_de.json`

## Layout

```text
tontooboot/
├── refind.conf
├── theme.conf
├── install-tontooboot.sh
├── selection-big.png
├── selection-small.png
├── icons/
│   ├── os_tontoo.svg
│   ├── tool_recovery.svg
│   └── background.svg
└── lang/
    ├── en_us.json
    └── de_de.json
```

`selection-big.png` (144x144) and `selection-small.png` (48x48) are
pre-rendered orange `#ff6b2b` selection rings, committed to the repo so
no Python is needed at install time.

## Install on target

```bash
pacman -S refind
bash install-tontooboot.sh --esp /efi
```

## Live ISO staging

`BaseOS/scripts/stage-tontooboot.sh` copies this theme to
`/usr/share/tontooboot` and the installer to
`/usr/local/lib/baseos-setup/install-tontooboot.sh`.

#!/usr/bin/env bash
set -euo pipefail

# Set MacTahoe Cursors as default cursor theme
mkdir -p etc/skel/.config

# Cursor theme config
cat > etc/skel/.config/kcminputrc << 'EOF'
[Mouse]
cursorTheme=MacTahoe-dark-cursors
cursorSize=24
EOF

# GTK configs
mkdir -p etc/skel/.config/gtk-3.0
cat > etc/skel/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-cursor-theme-name=MacTahoe-dark-cursors
gtk-cursor-theme-size=24
gtk-font-name=SF Pro Display 10
gtk-theme-name=TontooOS-Dark
gtk-decoration-layout=close,minimize,maximize:
gtk-application-prefer-dark-theme=1
EOF

mkdir -p etc/skel/.config/gtk-4.0
cat > etc/skel/.config/gtk-4.0/settings.ini << 'EOF'
[Settings]
gtk-cursor-theme-name=MacTahoe-dark-cursors
gtk-cursor-theme-size=24
gtk-font-name=SF Pro Display 10
gtk-theme-name=TontooOS-Dark
gtk-decoration-layout=close,minimize,maximize:
gtk-application-prefer-dark-theme=1
EOF

# Sound theme + KDE default font
cat > etc/skel/.config/kdeglobals << 'EOF'
[General]
font=SF Pro Display,10,-1,5,50,0,0,0,0,0
menuFont=SF Pro Display,10,-1,5,50,0,0,0,0,0
smallestReadableFont=SF Pro Display,8,-1,5,50,0,0,0,0,0
toolBarFont=SF Pro Display,10,-1,5,50,0,0,0,0,0
fixed=SF Pro Text,10,-1,5,50,0,0,0,0,0
SoundThemeName=tontoosounds
EOF

# Ensure LaunchPad services directory exists
mkdir -p System/services

# Ensure machine-id is empty so systemd generates a fresh one on boot
# (prevents dconf "Cannot spawn a message bus without a machine-id")
: > etc/machine-id

# Compile glib schemas so 90_tontoo.gschema.override (TontooOS-Dark, prefer-dark, Ampeln links) takes effect
if [ -d usr/share/glib-2.0/schemas ]; then
  glib-compile-schemas usr/share/glib-2.0/schemas || echo "warning: glib-compile-schemas failed"
fi

# Ensure compositor starter and other local scripts are executable (Windows host may lose +x)
chmod 0755 usr/local/bin/start-compositor.sh 2>/dev/null || true
chmod 0755 usr/local/bin/start-menubar.sh 2>/dev/null || true
chmod 0755 usr/local/bin/baseos-setup-session 2>/dev/null || true
chmod 0755 usr/local/bin/tapp-binfmt.sh 2>/dev/null || true
chmod 0755 usr/local/bin/tontoo-net-up.sh 2>/dev/null || true
chmod 0755 usr/local/bin/tontoo-sshd.sh 2>/dev/null || true

# Rebuild font cache so the SF Pro fonts are available at first boot
fc-cache -f -v

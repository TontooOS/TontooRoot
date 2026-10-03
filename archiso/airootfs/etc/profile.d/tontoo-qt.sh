# TontooOS Qt/Electron defaults for login shells (matches the compositor
# session env in apply_color_scheme_env; tontoo-theme-apply writes the
# matching qt5ct/qt6ct configs).
export QT_QPA_PLATFORMTHEME=qt5ct
export ELECTRON_OZONE_PLATFORM_HINT=auto

# Qt paints client-side decoration titlebars itself through a
# wayland-decoration-client plugin (stock Qt ships "bradient", which draws
# window buttons on the right). "tontoo" is the TontooOS plugin that draws
# macOS traffic lights on the left instead.
export QT_WAYLAND_DECORATION=tontoo

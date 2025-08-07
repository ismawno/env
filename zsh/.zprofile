# Launch Hyprland only on TTY1 and only if it's installed and not already running
# if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && command -v Hyprland >/dev/null 2>&1; then
#   exec Hyprland
# fi


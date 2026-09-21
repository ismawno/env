#!/usr/bin/env bash

# One lock, or two quick presses both find the bar already gone and both start one.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-restart.lock"
flock 9

# NixOS runs the bar as .waybar-wrapped, so match the command line, and only the main bar's config.
main='waybar -c [^ ]*/waybar/config'
pkill -f "$main"
for _ in {1..30}; do
  pgrep -f "$main" >/dev/null || break
  sleep 0.1
done

# Closing fd 9 in the child: an inherited lock would block the next press forever.
waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css 9>&- &

# The lock is only worth holding until the new bar is matchable by the next press.
for _ in {1..30}; do
  pgrep -f "$main" >/dev/null && break
  sleep 0.1
done

# swaync belongs to its systemd user unit; a hand-started copy makes that unit fail.
systemctl --user restart swaync.service
notify-send -u low "Waybar restarted"

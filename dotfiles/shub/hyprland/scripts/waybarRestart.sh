#!/usr/bin/env bash

# NixOS runs the bar as .waybar-wrapped, so match the command line, and only the main bar's config.
main='waybar -c [^ ]*/waybar/config'
pkill -f "$main"
for _ in {1..30}; do
  pgrep -f "$main" >/dev/null || break
  sleep 0.1
done

waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css &

# swaync belongs to its systemd user unit; a hand-started copy makes that unit fail.
systemctl --user restart swaync.service
notify-send -u low "Waybar restarted"

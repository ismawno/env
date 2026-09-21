#!/usr/bin/env bash
# One lock, or two quick presses both find the bar already gone and both start one.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-restart.lock"
flock 9

# NixOS runs the bar as .waybar-wrapped, so match the command line; the variant in use is read off the running bar.
bar='waybar -c [^ ]*/waybar/config(-cava)?( |$)'
variant=config
pgrep -f 'waybar -c [^ ]*/waybar/config-cava( |$)' >/dev/null && variant=config-cava
if [ "${1:-}" = toggle ]; then
  [ "$variant" = config ] && variant=config-cava || variant=config
fi

pkill -f "$bar"
for _ in {1..30}; do
  pgrep -f "$bar" >/dev/null || break
  sleep 0.1
done
# cava outlives the bar that spawned it and is reparented to init.
pkill -f 'scripts/waybarCava.sh'
pkill -f 'cava -p [^ ]*bar_cava_config'

# Closing fd 9 in the child: an inherited lock would block the next press forever.
waybar -c ~/.config/waybar/"$variant" -s ~/.config/waybar/style.css >/dev/null 2>&1 9>&- &

# The lock is only worth holding until the new bar is matchable by the next press.
for _ in {1..30}; do
  pgrep -f "$bar" >/dev/null && break
  sleep 0.1
done

[ "${1:-}" = toggle ] && exit 0
# swaync belongs to its systemd user unit; a hand-started copy makes that unit fail.
systemctl --user restart swaync.service
notify-send -u low "Waybar restarted"

#!/usr/bin/env bash

# One lock, or two quick presses both find no bar and both start one.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-lumi.lock"
flock 9

lumi='waybar -c [^ ]*/waybar/lumi-config'
if pkill -f "$lumi"; then
  for _ in {1..30}; do
    pgrep -f "$lumi" >/dev/null || break
    sleep 0.1
  done
  # cava outlives the bar that spawned it and is reparented to init.
  pkill -f 'scripts/waybarCava.sh'
  pkill -f 'cava -p [^ ]*bar_cava_config'
  exit 0
fi

# Closing fd 9 in the child: an inherited lock would block the next press forever.
waybar -c ~/.config/waybar/lumi-config -s ~/.config/waybar/style.css >/dev/null 2>&1 9>&- &

# The lock is only worth holding until the new bar is matchable by the next press.
for _ in {1..30}; do
  pgrep -f "$lumi" >/dev/null && break
  sleep 0.1
done

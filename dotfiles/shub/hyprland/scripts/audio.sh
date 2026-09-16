#!/usr/bin/env bash
# Waybar sound module, middle click: same content as the hover tooltip.
set -uo pipefail

command -v pactl >/dev/null 2>&1 || exit 0
sink=$(pactl get-default-sink 2>/dev/null) || exit 0

desc=$(pactl -f json list sinks 2>/dev/null | python3 -c '
import json, sys
try: sinks = json.load(sys.stdin)
except Exception: raise SystemExit
want = sys.argv[1]
for s in sinks:
    if s.get("name") == want:
        print(s.get("description") or want)
        break
' "$sink" 2>/dev/null)
[ -z "$desc" ] && desc=$sink

vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]\+%' | head -1)
mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
[ "$mute" = "yes" ] && state="muted" || state="${vol:-?}"

notify-send -a waybar "Audio" "$desc
$state" 2>/dev/null || echo "notify-send not found" >&2

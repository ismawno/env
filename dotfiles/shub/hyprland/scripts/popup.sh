#!/usr/bin/env bash
# Float a command centred at a share of the focused monitor (waybar clicks, rofi entries); -g runs it without a terminal.
set -uo pipefail

GUI=0
[ "${1:-}" = "-g" ] && { GUI=1; shift; }

if [[ "${1:-}" =~ ^[0-9]+$ && "${2:-}" =~ ^[0-9]+$ ]]; then
  PW=$1; PH=$2; shift 2
else
  PW=75; PH=75
fi
[ $# -gt 0 ] || { echo "usage: popup.sh [-g] [w% h%] <command...>" >&2; exit 1; }

[ "$GUI" -eq 1 ] && CMD="$*" || CMD="ghostty -e $*"
# hyprctl dispatch does nothing under the Lua config, so the launch goes through eval.
out=$(hyprctl eval "hl.exec_cmd([==[$CMD]==], { float = true, center = true, size = \"(monitor_w*$PW/100) (monitor_h*$PH/100)\" })" 2>&1)
[ "$out" = "ok" ] || { echo "popup.sh: $out" >&2; exit 1; }

#!/usr/bin/env bash
# Float a command centred, sized to the focused monitor; Hyprland ignores percent.
# popup.sh btop | popup.sh 60 60 nmtui | popup.sh -g 60 60 pavucontrol
set -uo pipefail

GUI=0
[ "${1:-}" = "-g" ] && { GUI=1; shift; }

if [[ "${1:-}" =~ ^[0-9]+$ && "${2:-}" =~ ^[0-9]+$ ]]; then
  PW=$1; PH=$2; shift 2
else
  PW=75; PH=75
fi
[ $# -gt 0 ] || { echo "usage: popup.sh [-g] [w% h%] <command...>" >&2; exit 1; }

read -r MW MH < <(hyprctl monitors -j 2>/dev/null | python3 -c '
import json,sys
try: ms=json.load(sys.stdin)
except Exception: print("1920 1080"); raise SystemExit
m=next((x for x in ms if x.get("focused")), ms[0] if ms else None)
if not m: print("1920 1080"); raise SystemExit
s=m.get("scale",1) or 1
print(int(m["width"]/s), int(m["height"]/s))
' 2>/dev/null) || { MW=1920; MH=1080; }

W=$(( MW * PW / 100 )); H=$(( MH * PH / 100 ))
[ "$GUI" -eq 1 ] && CMD="$*" || CMD="ghostty -e $*"
hyprctl dispatch exec "[float;size $W $H;centerwindow] $CMD" >/dev/null 2>&1

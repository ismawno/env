#!/usr/bin/env bash
# Float a command centred at a share of the focused monitor, or travel to the one it already opened and focus it; -g runs it without a terminal.
set -uo pipefail

GUI=0
CLASS=
while [ $# -gt 0 ]; do
  case $1 in
    -g) GUI=1 ;;
    -c) CLASS=${2:-}; shift ;;
    *) break ;;
  esac
  shift
done

if [[ "${1:-}" =~ ^[0-9]+$ && "${2:-}" =~ ^[0-9]+$ ]]; then
  PW=$1; PH=$2; shift 2
else
  PW=75; PH=75
fi
[ $# -gt 0 ] || { echo "usage: popup.sh [-g] [-c class] [w% h%] <command...>" >&2; exit 1; }

# An app id of its own is what lets the next click find this window instead of making a second one.
if [ "$GUI" -eq 1 ]; then
  CMD="$*"
else
  CLASS=${CLASS:-shub.popup.$1}
  CMD="ghostty --class=$CLASS -e $*"
fi

LUA="hl.exec_cmd([==[$CMD]==], { float = true, center = true, size = '(monitor_w*$PW/100) (monitor_h*$PH/100)' })"

if [ -n "$CLASS" ]; then
  # A window still mapping is invisible to get_windows, so its process stands in for it between the two presses.
  pgrep -fx "$CMD" >/dev/null && STARTING=true || STARTING=false
  LUA=$(cat <<LUA
local w
for _, c in ipairs(hl.get_windows({ class = [==[$CLASS]==] })) do
  if not w or c.focus_history_id < w.focus_history_id then w = c end
end
if w then
  local dsp, ws = hl.dsp, w.workspace
  if ws.special then
    local mon = ws.monitor
    if mon and not mon.focused then hl.dispatch(dsp.focus({ monitor = mon.name })) end
    local shown = hl.get_active_special_workspace(mon)
    if not shown or shown.id ~= ws.id then hl.dispatch(dsp.workspace.toggle_special((ws.name:gsub('^special:', '')))) end
  else
    hl.dispatch(dsp.focus({ workspace = ws.id > 0 and ws.id or ('name:' .. ws.name) }))
    local shown = hl.get_active_special_workspace()
    if shown then hl.dispatch(dsp.workspace.toggle_special((shown.name:gsub('^special:', '')))) end
  end
  hl.dispatch(dsp.focus({ window = 'address:' .. w.address }))
  hl.dispatch(dsp.window.bring_to_top({ window = 'address:' .. w.address }))
  w = hl.get_window('address:' .. w.address)
  if w then hl.dispatch(dsp.cursor.move({ x = math.floor(w.at.x + w.size.x / 2), y = math.floor(w.at.y + w.size.y / 2) })) end
elseif not $STARTING then
  $LUA
end
LUA
)
fi

# hyprctl dispatch does nothing under the Lua config, so the whole decision goes through one eval.
out=$(hyprctl eval "$LUA" 2>&1)
[ "$out" = "ok" ] || { echo "popup.sh: $out" >&2; exit 1; }

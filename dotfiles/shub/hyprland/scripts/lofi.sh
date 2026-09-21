#!/usr/bin/env bash

# Online radio. No argument toggles the picker, as Super+Shift+A always did; "tasks", "play <station>" and "stop" are for the rofi tasks mode.

set -u

stations="$(dirname "$(readlink -f "$0")")/lofi-stations.tsv"

list() {
  grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$stations"
}

play() {
  local name="$1" link
  link=$(list | awk -F '\t' -v name="$name" '$1 == name { print $2; exit }')
  if [ -z "$link" ]; then
    notify-send -u critical "Online Music" "no station named $name"
    exit 1
  fi
  pkill mpv
  notify-send -u normal "Playing now: $name"
  case "$link" in
  *playlist* | *watch*) exec mpv --shuffle --vid=no --volume=50 "$link" ;;
  *) exec mpv --volume=50 "$link" ;;
  esac
}

case "${1-}" in
tasks)
  list | cut -f 1 | while IFS= read -r name; do
    printf '> Radio: %s\t%s play '"'"'%s'"'"'\n' "$name" "$0" "$name"
  done
  printf '> Radio: Stop\t%s stop\n' "$0"
  ;;
play)
  play "$2"
  ;;
stop)
  pkill mpv && notify-send -u low "Online Music stopped"
  ;;
"")
  if pkill mpv; then
    notify-send -u low "Online Music stopped"
  else
    choice=$(list | cut -f 1 | rofi -i -dmenu -config ~/.config/rofi/config.rasi -p "")
    [ -n "$choice" ] && play "$choice"
  fi
  ;;
*)
  echo "usage: $(basename "$0") [tasks|play <station>|stop]" >&2
  exit 1
  ;;
esac

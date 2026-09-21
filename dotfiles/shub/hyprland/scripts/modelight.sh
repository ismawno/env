#!/usr/bin/env bash
# Waybar: power profile + night light in one module, rendered "[MODE/LIGHT]"; light toggling defers to hyprsunset.sh.

here=$(dirname "$(readlink -f "$0")")
sig=10   # waybar "signal": 10  ->  pkill -RTMIN+10 waybar
cmd=${1:-status}

# PPD is absent on bigsys; the firmware profile is shown instead, read-only because only root can set it.
have_ppd=0
current=""
profiles=()
if command -v powerprofilesctl >/dev/null 2>&1 && current=$(powerprofilesctl get 2>/dev/null); then
  have_ppd=1
  mapfile -t profiles < <(powerprofilesctl list 2>/dev/null \
    | grep -oE '^[* ] [a-z-]+:' | tr -d '*: ' | sed '/^$/d')
  [ ${#profiles[@]} -eq 0 ] && profiles=(power-saver balanced performance)
elif [ -r /sys/firmware/acpi/platform_profile ]; then
  current=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)
fi

mode_label() {
  case "$1" in
    power-saver|low-power)         echo ECO ;;
    balanced|balanced-performance) echo BAL ;;
    performance)                   echo PERF ;;
    "")                            echo "X" ;;
    *) printf '%s' "${1:0:4}" | tr '[:lower:]' '[:upper:]' ;;
  esac
}

night_on() { pgrep -x hyprsunset >/dev/null 2>&1; }

# Emits literal \n two-char sequences; printf %s passes them into the JSON as-is.
build_tooltip() {
  local tt="<b>Power profile</b>\n" p
  if [ "$have_ppd" -eq 1 ]; then
    for p in "${profiles[@]}"; do
      if [ "$p" = "$current" ]; then tt+=" * ${p}\n"; else tt+="   ${p}\n"; fi
    done
  elif [ -n "$current" ]; then
    tt+="   ${current}  (firmware, read-only)\n   power-profiles-daemon not running\n"
  else
    tt+="   unavailable  (no power-profiles-daemon)\n"
  fi
  tt+="\n<b>Night light</b>\n"
  if night_on; then
    tt+="   on   hyprsunset 4500K\n"
  else
    tt+="   off  native temperature\n"
  fi
  printf '%s' "$tt"
}

case "$cmd" in
  cycle-mode|cycle)
    if [ "$have_ppd" -eq 1 ]; then
      next=${profiles[0]}
      for i in "${!profiles[@]}"; do
        [ "${profiles[$i]}" = "$current" ] && { next=${profiles[$(( (i + 1) % ${#profiles[@]} ))]}; break; }
      done
      powerprofilesctl set "$next" 2>/dev/null
    elif command -v notify-send >/dev/null 2>&1; then
      notify-send -a waybar "Power profile" "power-profiles-daemon is not available on this host"
    fi
    pkill -RTMIN+$sig waybar 2>/dev/null
    ;;
  toggle-light|toggle)
    "$here/hyprsunset.sh"
    sleep 0.3   # let hyprsunset appear/vanish in the process table before re-reading
    pkill -RTMIN+$sig waybar 2>/dev/null
    ;;
  info)
    command -v notify-send >/dev/null 2>&1 &&
      notify-send -a waybar "Mode / Light" "$(build_tooltip | sed 's/<[^>]*>//g; s/\\n/\n/g')"
    ;;
  status)
    mode=$(mode_label "$current")
    if night_on; then light=NIGHT; lclass=night; else light=DAY; lclass=day; fi
    [ "$have_ppd" -eq 1 ] && mclass=$current || mclass=absent
    printf '{"text":"[%s]/[%s]","tooltip":"%s","class":["%s","%s"]}\n' \
      "$mode" "$light" "$(build_tooltip)" "$mclass" "$lclass"
    ;;
esac

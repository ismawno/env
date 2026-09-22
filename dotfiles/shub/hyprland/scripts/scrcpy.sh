#!/usr/bin/env bash
pkill -u "$UID" -x scrcpy && exit

mapfile -t devices < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [ "${#devices[@]}" -eq 0 ]; then
    notify-send "No devices connected."
    exit 1
fi

device=${devices[0]}
if [ "${#devices[@]}" -gt 1 ]; then
    device=$(printf '%s\n' "${devices[@]}" | rofi -dmenu -config ~/.config/rofi/config.rasi -p "Select Device: ")
fi
if [ -z "$device" ]; then
    echo "No device selected."
    exit 1
fi

case $(printf 'Video\nNo Video\nVideo & Audio\n' | rofi -dmenu -config ~/.config/rofi/config.rasi -p "Select SCRCPY mode: ") in
    "Video") scrcpy --serial "$device" --no-audio ;;
    "No Video") scrcpy --serial "$device" --no-window ;;
    "Video & Audio") scrcpy --serial "$device" ;;
    *) echo "Invalid selection" ;;
esac

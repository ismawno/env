#!/usr/bin/bash

#Restart Waybar and swaync

killall waybar
waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css &
# swaync belongs to its systemd user unit; a hand-started copy makes that unit fail.
systemctl --user restart swaync.service
notify-send --app-name=HOME -i ~/.config/fastfetch/moon.png Hello

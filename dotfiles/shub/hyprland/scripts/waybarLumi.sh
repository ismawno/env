#!/usr/bin/env bash
# Toggles the extra cava bar: a second press takes it away again.
pkill -f "waybar -c .*/lumi-config" || waybar -c ~/.config/waybar/lumi-config -s ~/.config/waybar/style.css &

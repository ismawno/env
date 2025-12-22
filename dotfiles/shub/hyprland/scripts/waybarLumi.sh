#!/usr/bin/env bash

killall waybar
waybar -c ~/.config/waybar/lumi-config -s ~/.config/waybar/style.css &

#!/usr/bin/env bash

pkill -x waybar
waybar -c ~/.config/waybar/lumi-config -s ~/.config/waybar/style.css &

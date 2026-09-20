#!/usr/bin/env bash

#Script for lockscreen

sleep 2
command -v powerprofilesctl >/dev/null && powerprofilesctl set power-saver
hyprlock -c ~/.config/hypr/hyprlock/hyprlock.conf
command -v powerprofilesctl >/dev/null && powerprofilesctl set performance

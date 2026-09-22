#!/usr/bin/env bash
# Taken from JaKoolit's dotfiles
bar="▁▂▃▄▅▆▇█"
dict="s/;//g"
for ((i = 0; i < ${#bar}; i++)); do
    dict+=";s/$i/${bar:$i:1}/g"
done

config_file="${XDG_RUNTIME_DIR:-/tmp}/bar_cava_config"
cat >"$config_file" <<EOF
[general]
bars = 10

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

pkill -u "$UID" -f "cava -p $config_file"

cava -p "$config_file" | sed -u "$dict"

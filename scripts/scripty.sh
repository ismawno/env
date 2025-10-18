#!/bin/sh
for i in {4..1}; do
    tmux move-window -s $i -t $((i + 1))
done


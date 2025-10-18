#!/bin/sh

dirs="../dotfiles ../.config/nvim ../convoy ../toolkit ../vulkit ../onyx ../drizzle"

python src/for_each.py --ignore-cmd-errors -v -y -d $dirs -c "$1"

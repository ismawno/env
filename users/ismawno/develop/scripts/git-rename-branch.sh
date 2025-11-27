#!/bin/sh

show_usage() {
  cat <<EOF
Usage: $(basename "$0") <name1> [name2]

Rename a git branch both locally and remotely (if applicable).

Arguments:
  <name1>      Treated as the new name when only 1 argument is provided, or the old name when 2 arguments are provided
  [name2]      The branch's new name

Options:
  -h, --help      Show this help message and exit.
EOF
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  echo "Error: missing required arguments."
  echo
  show_usage
  exit 1
fi

if [ "$#" -eq 1 ]; then
  old=$(git branch --show-current)
  new="$1"
else
  old="$1"
  new="$2"
fi

git branch -m "$old" "$new"
git push origin "$new"
git push origin -d "$old"
git push --set-upstream origin "$new"

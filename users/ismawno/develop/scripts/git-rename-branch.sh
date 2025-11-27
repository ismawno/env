#!/bin/sh

set -e

show_usage() {
  cat <<EOF
Usage: $(basename "$0") <name1> [name2]

Rename a git branch both locally and remotely (if applicable).

Arguments:
  <name1>      With one argument: the new name of the current branch.
               With two arguments: the old branch name.
  [name2]      The new branch name (only when two arguments are provided).

Options:
  -h, --help   Show this help message and exit.
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
  if [ -z "$old" ]; then
    echo "Error: unable to detect current branch."
    exit 1
  fi
  new="$1"
else
  old="$1"
  new="$2"
fi

remote_branch_exists() {
  git ls-remote --heads origin "$1" | grep -q .
}

if ! git rev-parse --verify --quiet "refs/heads/$old" >/dev/null; then
    if remote_branch_exists "$old"; then
        echo "Remote branch '$old' exists. Creating local tracking branch..."
    git fetch origin "$old"
    git branch "$old" "origin/$old"
else
  echo "Error: branch '$old' does not exist."
  exit 1
fi
fi

git branch -m "$old" "$new"


if remote_branch_exists "$old"; then
  echo "Remote branch '$old' exists. Updating..."

  git push --set-upstream origin "$new"
  git push origin --delete "$old"
else
  echo "No remote branch '$old' found. Local rename only."
fi


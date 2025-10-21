#!/bin/sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
show_usage() {
  cat <<EOF
Usage: $(basename "$0") [flake-path]

Rebuild a user configuration.

Arguments:
  [flake-path]      Optional path to the flake (default: $SCRIPT_DIR)

Options:
  -h, --help      Show this help message and exit.
EOF
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
FLAKE_PATH="${1:-$SCRIPT_DIR}"

echo "Flake path is $FLAKE_PATH"

nix flake update nvim

echo "Rebuilding user $USER..."

home-manager switch --flake "$FLAKE_PATH"

current=$(home-manager generations | head -n1 | awk '{print $5}')

if git diff --quiet && git diff --cached --quiet; then
    exit 0
fi

git add .
git commit -m "rebuild: user configuration generation for user '$USER' with host '$(hostname -s)' - $current"



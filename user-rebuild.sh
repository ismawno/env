#!/bin/sh

set -e

show_usage() {
  cat <<EOF
Usage: $(basename "$0") <configuration> [flake-path]

Rebuild a user configuration.

Arguments:
  <configuration>   The user configuration to build (e.g., "ismawno")
  [flake-path]      Optional path to the flake (default: $HOME/env)

Options:
  -h, --help      Show this help message and exit.
EOF
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_usage
  exit 0
fi

# Validate arguments
if [ "$#" -lt 1 ]; then
  echo "Error: missing required arguments."
  echo
  show_usage
  exit 1
fi

USER="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
FLAKE_PATH="${2:-$SCRIPT_DIR}"

echo "Flake path is $FLAKE_PATH"

nix flake update nvim

echo "Rebuilding user $USER..."

home-manager switch --flake "$FLAKE_PATH#$USER"

current=$(nixos-rebuild list-generations | grep current | awk '{print $1}')

if git diff --quiet && git diff --cached --quiet; then
    exit 0
fi

git add .
git commit -m "rebuild: user configuration generation for $USER - $current"



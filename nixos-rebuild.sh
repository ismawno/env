#!/bin/sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
show_usage() {
  cat <<EOF
Usage: $(basename "$0") <hostname> [flake-path]

Rebuild a NixOS hostname given a host name.

Arguments:
  <hostname>        The hostname from which to build the NixOS configuration (e.g., "nomad")
  [flake-path]      Optional path to the flake (default: $SCRIPT_DIR)

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

HOST_NAME="$1"

FLAKE_PATH="${2:-$SCRIPT_DIR}"

echo "Flake path is $FLAKE_PATH"

nix flake update nvim

echo "Rebuilding NixOS with host $HOST_NAME..."

sudo nixos-rebuild switch --flake "$FLAKE_PATH#$HOST_NAME"

current=$(nixos-rebuild list-generations | grep current | awk '{print $1}')

if git diff --quiet && git diff --cached --quiet; then
    exit 0
fi

git add .
git commit -m "rebuild: NixOS hostname generation for $HOST_NAME - $current"



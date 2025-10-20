#!/bin/sh

set -e


show_usage() {
  cat <<EOF
Usage: $(basename "$0") <hostname> [flake-path]

Rebuild a NixOS configuration for the given hostname.

Arguments:
  <hostname>      The hostname of the NixOS configuration to build (e.g., "desktop" or "laptop").
  [flake-path]    Optional path to the flake (default: $HOME/env)

Options:
  -h, --help      Show this help message and exit.

Examples:
  $(basename "$0") desktop
  $(basename "$0") laptop ~/my-flakes/nixos
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

HOSTNAME="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
SCRIPT_DIR="$(realpath "$SCRIPT_DIR/..")"

FLAKE_PATH="${2:-$SCRIPT_DIR}"

echo "Flake path is $FLAKE_PATH"

sudo nix flake update nvim

echo "NixOS Rebuilding..."

export ROOT_PATH="$SCRIPT_DIR"
sudo --preserve-env=ROOT_PATH nixos-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"
unset ROOT_PATH

current=$(nixos-rebuild list-generations | grep current | awk '{print $1}')
git commit -am "rebuild: NixOS configuration generation: $current"



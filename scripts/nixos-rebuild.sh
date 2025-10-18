#!/bin/sh
set -e

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <hostname>"
  exit 1
fi

pushd ~/env

sudo nix flake update nvim

echo "NixOS Rebuilding..."

sudo nixos-rebuild switch --flake ~/env#$1

current=$(nixos-rebuild list-generations | grep current | awk '{print $1}')

git commit -am "rebuild: NixOS configuration generation: $current"

popd

#!/bin/sh
set -e

pushd ~/env

sudo nix flake update nvim

git diff -U0 '*.nix'

echo "NixOS Rebuilding..."

sudo nixos-rebuild switch --flake ~/env#$1

current=$(nixos-rebuild list-generations | grep current)

git commit -am "$current"

popd

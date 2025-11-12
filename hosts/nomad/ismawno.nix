{ config, pkgs, ... }:

let
  dotfiles = ../../dotfiles/vanilla;
in
{
  home.packages = with pkgs; [
    hyprlock
    hypridle
    pamixer
    brightnessctl
  ];

  home.file = {
    ".config/hypr/hyprlock.conf".source = "${dotfiles}/hyprlock/.config/hypr/hyprlock.conf";
    ".config/hypr/hypridle.conf".source = "${dotfiles}/hyprlock/.config/hypr/hypridle.conf";
  };

  home.stateVersion = "25.05";
}

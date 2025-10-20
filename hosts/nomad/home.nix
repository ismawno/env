{ config, pkgs, ... }:

{
  home.file = {
    ".config/hypr/hyprlock.conf".source =
      ../../hyprlock/.config/hypr/hyprlock.conf;
    ".config/hypr/hypridle.conf".source =
      ../../hyprlock/.config/hypr/hypridle.conf;
  };

  home.stateVersion = "25.05";
}


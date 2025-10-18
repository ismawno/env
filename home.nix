{ config, pkgs, inputs, hostName, ... }:

let
  nomadSpecific = if hostName == "nomad" then {
    ".config/hypr/hyprlock".source = ./hyprlock/.config/hypr/hyprlock.conf;
    ".config/hypr/hypridle".source = ./hyprlock/.config/hypr/hypridle.conf;
  } else
    { };
in {
  home.username = "ismawno";
  home.homeDirectory = "/home/ismawno";

  programs.git.enable = true;

  home.file = {
    ".zshrc".source = ./zsh/.zshrc;
    ".p10k.zsh".source = ./zsh/.p10k.zsh;
    ".tmux.conf".source = ./tmux/.tmux.conf;

    ".config/nvim".source = inputs.nvim;
    ".config/hypr/hyprland.conf".source = ./hyprland/.config/hypr/hyprland.conf;
    ".config/hypr/hyprpaper.conf".source =
      ./hyprland/.config/hypr/hyprpaper.conf;
    ".config/hypr/mocha.conf".source = ./hyprland/.config/hypr/mocha.conf;
    ".config/ghostty".source = ./ghostty/.config/ghostty;
    ".config/waybar".source = ./waybar/.config/waybar;
    ".config/wofi".source = ./wofi/.config/wofi;
    ".config/backgrounds".source = ./backgrounds/.config/backgrounds;
  } // nomadSpecific;

  home.stateVersion = "25.05";
}


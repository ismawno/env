{ config, pkgs, ... }:

{
  home.username = "ismawno";
  home.homeDirectory = "/home/ismawno";

  programs.git.enable = true;

  home.file.".zshrc".source = ./zsh/.zshrc
  home.file.".p10k.zsh".source = ./zsh/.p10k.zsh

  home.file.".tmux.conf".source = ./tmux/.tmux.conf

  home.file.".config/hypr".source = ./hyprland/.config/hypr;
  home.file.".config/ghostty".source = ./ghostty/.config/ghostty;
  home.file.".config/waybar".source = ./waybar/.config/waybar;
  home.file.".config/wofi".source = ./wofi/.config/wofi;

  home.stateVersion = "25.05";
}


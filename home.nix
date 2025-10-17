{ config, pkgs, inputs, ... }:

{
  home.username = "ismawno";
  home.homeDirectory = "/home/ismawno";

  programs.git.enable = true;

  home.file.".zshrc".source = ./zsh/.zshrc;
  home.file.".p10k.zsh".source = ./zsh/.p10k.zsh;

  home.file.".tmux.conf".source = ./tmux/.tmux.conf;

  home.file.".config/nvim".source = inputs.nvim;
  home.file.".config/hypr".source = ./hyprland/.config/hypr;
  home.file.".config/ghostty".source = ./ghostty/.config/ghostty;
  home.file.".config/waybar".source = ./waybar/.config/waybar;
  home.file.".config/wofi".source = ./wofi/.config/wofi;
  home.file.".config/backgrounds".source = ./backgrounds/.config/backgrounds;

  home.stateVersion = "25.05";
}


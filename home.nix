{ config, pkgs, inputs, ... }:

{
  home.username = "ismawno";
  home.homeDirectory = "/home/ismawno";

  programs.git.enable = true;

  home.file = {
    ".zshrc".source = ./zsh/.zshrc;
    ".p10k.zsh".source = ./zsh/.p10k.zsh;
    ".tmux.conf".source = ./tmux/.tmux.conf;
    ".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0"; # check the latest release
      sha256 = "18i499hhxly1r2bnqp9wssh0p1v391cxf10aydxaa7mdmrd3vqh9";
    };

    ".config/nvim".source = inputs.nvim;
    ".config/hypr/hyprland.conf".source = ./hyprland/.config/hypr/hyprland.conf;
    ".config/hypr/hyprpaper.conf".source =
      ./hyprland/.config/hypr/hyprpaper.conf;
    ".config/hypr/mocha.conf".source = ./hyprland/.config/hypr/mocha.conf;
    ".config/ghostty".source = ./ghostty/.config/ghostty;
    ".config/waybar".source = ./waybar/.config/waybar;
    ".config/wofi".source = ./wofi/.config/wofi;
    ".config/backgrounds".source = ./backgrounds/.config/backgrounds;
  };

  home.stateVersion = "25.05";
}


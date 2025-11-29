{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  dotfiles = ../../dotfiles/vanilla;
in
{
  home.packages = with pkgs; [
    zoxide
    ghostty
    ripgrep
    wofi
    fzf
    waybar
    hyprpaper
    firefox
    nodejs_22
    unzip
    tmux
    hwloc
    pulseaudio
    catppuccin-cursors.mochaDark
    neofetch
    htop
    shellcheck
    stylua
    lua-language-server
    vscode-extensions.vadimcn.vscode-lldb.adapter
    nixfmt-rfc-style
    vscode-langservers-extracted
    nodePackages_latest.prettier
    black
    pyright
    shfmt
    bash-language-server
    cmake-language-server
    cmake-format
    glsl_analyzer
    # maybe temporary
    mpv
    spotify
    cava
    ollama
    gdu
  ];

  programs.git = {
    enable = true;
    userName = "Mars-Wave";
    userEmail = "tmorolias@protonmail.com";
    extraConfig = {
      credential.helper = "store";
    };
  };
  programs.vim.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
  programs.starship.enable = true;
  programs.zsh = {
    enable = true;
    sessionVariables = {
      MAD_ENV_PATH = "/home/maddev/env";
      MAD_NVIM_PATH = "/home/maddev/nvim";
      MAD_CONVOY_PATH = "/home/maddev/convoy";
      MAD_TOOLKIT_PATH = "/home/maddev/toolkit";
      MAD_ONYX_PATH = "/home/maddev/onyx";
      MAD_DRIZZLE_PATH = "/home/maddev/drizzle";
    };
  };

  home.username = "maddev";
  home.homeDirectory = lib.mkForce "/home/maddev";

  home.file = {
    ".tmux.conf".source = "${dotfiles}/tmux/.tmux.conf";
    ".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0"; # check the latest release
      sha256 = "18i499hhxly1r2bnqp9wssh0p1v391cxf10aydxaa7mdmrd3vqh9";
    };

    ".config/zsh/.zshrc".source = "${dotfiles}/zsh/.zshrc";
    ".config/starship.toml".source = "${dotfiles}/starship/.config/starship.toml";
    ".config/nvim".source = inputs.nvim;
    ".config/hypr/hyprland.conf".source = "${dotfiles}/hyprland/.config/hypr/hyprland.conf";
    ".config/hypr/hyprpaper.conf".source = "${dotfiles}/hyprland/.config/hypr/hyprpaper.conf";
    ".config/hypr/mocha.conf".source = "${dotfiles}/hyprland/.config/hypr/mocha.conf";
    ".config/ghostty".source = "${dotfiles}/ghostty/.config/ghostty";
    ".config/waybar".source = "${dotfiles}/waybar/.config/waybar";
    ".config/wofi".source = "${dotfiles}/wofi/.config/wofi";
    ".config/backgrounds".source = "${dotfiles}/backgrounds/.config/backgrounds";
  };

  home.stateVersion = "25.05";
}

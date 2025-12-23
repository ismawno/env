{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  projectdir = ../..;
  username = "ismawno";
  dotfiles = "${projectdir}/dotfiles/vanilla";
  homedir = "/home/${username}";
  userdir = "${projectdir}/users/${username}";
in
{
  home.username = "${username}";
  home.homeDirectory = "${homedir}";

  home.packages = with pkgs; [
    bash-language-server
    black
    blender
    catppuccin-cursors.mochaDark
    cava
    cloc
    cmake-format
    cmake-language-server
    firefox
    fzf
    gdu
    ghostty
    glsl_analyzer
    htop
    hwloc
    hyprpaper
    lua-language-server
    mpv
    neofetch
    nixfmt-rfc-style
    nodePackages_latest.prettier
    nodejs_22
    ollama
    pulseaudio
    pyright
    ripgrep
    shellcheck
    shfmt
    spotify
    stylua
    tmux
    unzip
    vscode-extensions.vadimcn.vscode-lldb.adapter
    vscode-langservers-extracted
    waybar
    wofi
    zoxide
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Ismael Bueno";
      user.email = "ismaelwno@gmail.com";
      credential.helper = "store";
      push.autoSetupRemote = true;
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
      WNO_ENV_PATH = "/home/ismawno/env";
      WNO_NVIM_PATH = "/home/ismawno/nvim";
      WNO_CONVOY_PATH = "/home/ismawno/convoy";
      WNO_TOOLKIT_PATH = "/home/ismawno/toolkit";
      WNO_ONYX_PATH = "/home/ismawno/onyx";
      WNO_DRIZZLE_PATH = "/home/ismawno/drizzle";
    };
    dotDir = "${config.home.homeDirectory}/.config/zsh";
  };

  home.activation.copyDevelop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Copying develop directory..."

    [ -d "$HOME/develop" ] && chmod -R u+rwX "$HOME/develop"

    rm -f "$HOME/develop/flake.nix"
    rm -rf "$HOME/develop/scripts"
    mkdir -p "$HOME/develop"

    cp "${userdir}/develop/flake.nix" "$HOME/develop"
    cp -r "${userdir}/develop/scripts" "$HOME/develop"
  '';

  home.file = {
    ".tmux.conf".source = "${dotfiles}/tmux/.tmux.conf";
    ".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0"; # check the latest release
      sha256 = "18i499hhxly1r2bnqp9wssh0p1v391cxf10aydxaa7mdmrd3vqh9";
    };

    # "develop/flake.nix".source = "${userdir}/develop/flake.nix";
    # "develop/scripts".source = "${userdir}/develop/scripts";

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

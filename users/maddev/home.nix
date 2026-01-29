{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  shub = ../../dotfiles/shub;
  vanilla = ../../dotfiles/vanilla;
in
{
  home.packages = with pkgs; [
    zoxide
    ripgrep
    fzf
    unzip
    htop
    gdu
    imagemagick
    
    kdePackages.kservice
    kdePackages.kio-extras

    gcc
    gnumake
    fd

    wakeonlan

    waybar
    hyprpaper
    hyprlock
    rofi
    swaynotificationcenter
    wlogout
    fastfetch
    hyprpicker
    hyprshot
    copyq
    nwg-look
    polkit_gnome

    librewolf
    ghostty
    kdePackages.dolphin
    mpv
    spotify
    cava
    ollama
    smile

    hyprsunset

    nodejs_22
    tmux
    hwloc
    pulseaudio

    imv 
    mpv
    
    wget    
    nmap
    
    gruvbox-gtk-theme
    gruvbox-dark-icons-gtk
    bibata-cursors
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji

    neofetch
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
  ];

  xdg.desktopEntries.mpv = {
    name = "mpv";
    genericName = "Multimedia Player";
    exec = "mpv --player-operation-mode=pseudo-gui %U";
    terminal = false;
    categories = [ "AudioVideo" "Audio" "Video" "Player" ];
    mimeType = [ "video/mp4" "video/mkv" "video/webm" ]; # (You can list more here if you want)
  };

  xdg.desktopEntries.imv = {
    name = "imv";
    genericName = "Image Viewer";
    exec = "imv %f";
    terminal = false;
    categories = [ "Graphics" "Viewer" ];
    mimeType = [ "image/bmp" "image/gif" "image/jpeg" "image/jpg" "image/png" "image/tiff" "image/webp" ];
  };

  # Associate MIME types for video and image opening
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # --- Images (imv) ---
      "image/bmp" = [ "imv.desktop" ];
      "image/gif" = [ "imv.desktop" ];
      "image/jpeg" = [ "imv.desktop" ];
      "image/jpg" = [ "imv.desktop" ];
      "image/pjpeg" = [ "imv.desktop" ];
      "image/png" = [ "imv.desktop" ];
      "image/tiff" = [ "imv.desktop" ];
      "image/webp" = [ "imv.desktop" ];
      "image/x-bmp" = [ "imv.desktop" ];
      "image/x-pcx" = [ "imv.desktop" ];
      "image/x-png" = [ "imv.desktop" ];
      "image/x-portable-anymap" = [ "imv.desktop" ];
      "image/x-portable-bitmap" = [ "imv.desktop" ];
      "image/x-portable-graymap" = [ "imv.desktop" ];
      "image/x-portable-pixmap" = [ "imv.desktop" ];
      "image/x-tga" = [ "imv.desktop" ];
      "image/x-xbitmap" = [ "imv.desktop" ];
      "image/heic" = [ "imv.desktop" ];

      # --- Videos (mpv) ---
      "video/mp4" = [ "mpv.desktop" ];
      "video/mkv" = [ "mpv.desktop" ];
      "video/x-matroska" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "video/quicktime" = [ "mpv.desktop" ]; # .mov files
      "video/x-msvideo" = [ "mpv.desktop" ]; # .avi files
      "video/x-flv" = [ "mpv.desktop" ];
      "video/mpeg" = [ "mpv.desktop" ];
      "video/ogg" = [ "mpv.desktop" ];
    };
  };

  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "Mars-Wave";
      user.email = "tmorolias@protonmail.com";
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

  home.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Bibata-Modern-Ice";
    HYPRCURSOR_SIZE = "24";
    GTK_THEME = "Gruvbox-Light";
  };

  gtk = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    theme = {
      name = "Gruvbox-Light";
      package = pkgs.gruvbox-gtk-theme;
    };
    iconTheme = {
      name = "oomox-gruvbox-dark";
      package = pkgs.gruvbox-dark-icons-gtk;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
    };
    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=0
      '';
    };
    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=0
      '';
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  home.username = "maddev";
  home.homeDirectory = lib.mkForce "/home/maddev";

  xdg.configFile = {
    "hypr".source = "${shub}/hyprland";
    "waybar".source = "${shub}/waybar";
    "rofi".source = "${shub}/rofi";
    "swaync".source = "${shub}/swaync";
    "wlogout".source = "${shub}/wlogout";
    "fastfetch".source = "${shub}/fastfetch";
    "kitty".source = "${shub}/kitty";
    "backgrounds".source = "${shub}/backgrounds";
    "ghostty".source = "${vanilla}/ghostty/.config/ghostty";
    "zsh/.zshrc".source = "${vanilla}/zsh/.zshrc";
    "starship.toml".source = "${vanilla}/starship/.config/starship.toml";
    "nvim".source = inputs.nvim;
  };

  home.file = {
    ".tmux.conf".source = "${vanilla}/tmux/.tmux.conf";
    ".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0";
      sha256 = "18i499hhxly1r2bnqp9wssh0p1v391cxf10aydxaa7mdmrd3vqh9";
    };
  };

  home.stateVersion = "25.11";
}

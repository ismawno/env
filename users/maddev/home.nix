{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  lib,
  ...
}:

let
  shub = ../../dotfiles/shub;
  vanilla = ../../dotfiles/vanilla;
in
{
  imports = [
    ./opencode.nix
    ../modules/zen.nix
    ../modules/hypr-host.nix
    ../modules/pkgs-unstable.nix
  ];

  home.packages = with pkgs; [
    # Delete in imv: ask first (detached, one prompt at a time, because imv waits for what it runs), then move the picture to ~/Pictures/Wallpapers-rejected.
    (writeShellScriptBin "imv-reject" ''
      exec 9>"$XDG_RUNTIME_DIR/imv-reject.lock"
      flock -n 9 || exit 0
      (
        choice=$(printf 'No\nYes' | rofi -dmenu -i -p "Remove $(basename "$1")?")
        [ "$choice" = Yes ] || exit 0
        mkdir -p "$HOME/Pictures/Wallpapers-rejected"
        mv "$1" "$HOME/Pictures/Wallpapers-rejected/" && imv-msg "$2" close
      ) >/dev/null 2>&1 </dev/null &
    '')

    pkgs-unstable.claude-code
    syncthing
    obsidian

    caligula
    bluetuith # TUI bluetooth manager, the nmtui of BT (waybar click target)
    discord
    zoxide
    ripgrep
    fzf
    unzip
    btop # waybar sysinfo click target; replaces htop, which duplicated it in rofi
    gdu
    imagemagick
    tree-sitter

    thunar
    thunar-archive-plugin
    thunar-volman
    tumbler
    file-roller

    gvfs

    gcc
    gnumake
    fd

    wakeonlan

    waybar
    hyprpaper
    hyprlock
    rofi
    swaynotificationcenter
    libnotify # notify-send: the waybar middle-click info actions need it
    wlogout
    fastfetch
    hyprpicker
    hyprshot
    copyq
    wl-clipboard
    nwg-look
    polkit_gnome

    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ghostty
    mpv
    playerctl
    scrcpy
    wdisplays
    android-tools
    qt6Packages.qt6ct
    spotify
    obs-studio
    cava
    ollama
    smile

    hyprsunset

    nodejs_22
    tmux
    hwloc
    pulseaudio
    pavucontrol # the mixer waybar's left click opens; pipewire-pulse backs it

    imv

    wget
    nmap

    gruvbox-gtk-theme
    gruvbox-dark-icons-gtk
    bibata-cursors
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji

    shellcheck
    stylua
    lua-language-server
    vscode-extensions.vadimcn.vscode-lldb.adapter
    nixfmt
    vscode-langservers-extracted
    prettier
    black
    pyright
    shfmt
    bash-language-server
    cmake-language-server
    cmake-format
    glsl_analyzer
    python3
  ];

  services.syncthing = {
    enable = true;
    tray.enable = true;
  };

  # TUI tools rofi would otherwise miss; Terminal=false because popup.sh dispatches its own ghostty.
  xdg.desktopEntries =
    let
      popup = "${config.home.homeDirectory}/.config/hypr/scripts/popup.sh";
    in
    {
      nmtui = {
        name = "Network Manager (nmtui)";
        genericName = "Network Configuration";
        exec = "${popup} 60 60 nmtui";
        terminal = false;
        icon = "network-wireless";
        categories = [
          "System"
          "Network"
        ];
      };

      bluetuith = {
        name = "Bluetooth (bluetuith)";
        genericName = "Bluetooth Manager";
        exec = "${popup} 60 60 bluetuith";
        terminal = false;
        icon = "bluetooth";
        categories = [
          "System"
          "Network"
        ];
      };

      # Shadows the packaged btop.desktop (same file id) to float it like the rest.
      btop = {
        name = "btop++";
        genericName = "System Monitor";
        exec = "${popup} 85 85 btop";
        terminal = false;
        icon = "btop";
        categories = [
          "System"
          "Monitor"
        ];
      };

      mpv = {
        name = "mpv";
        genericName = "Multimedia Player";
        exec = "mpv --player-operation-mode=pseudo-gui %U";
        terminal = false;
        categories = [
          "AudioVideo"
          "Audio"
          "Video"
          "Player"
        ];
        mimeType = [
          "video/mp4"
          "video/mkv"
          "video/webm"
        ];
      };

      imv = {
        name = "imv";
        genericName = "Image Viewer";
        exec = "imv-dir %f";
        terminal = false;
        categories = [
          "Graphics"
          "Viewer"
        ];
        mimeType = [
          "image/bmp"
          "image/gif"
          "image/jpeg"
          "image/jpg"
          "image/png"
          "image/tiff"
          "image/webp"
        ];
      };
    };

  # Associate MIME types for video and image opening
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "thunar.desktop" ];

      # --- Web (Zen) ---
      "x-scheme-handler/http" = [ "zen-beta.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" ];
      "text/html" = [ "zen-beta.desktop" ];
      "application/xhtml+xml" = [ "zen-beta.desktop" ];

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
      user.email = "57585293+Mars-Wave@users.noreply.github.com";
      credential.helper = "store";
    };
  };

  programs.vim.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;
  };

  programs.starship.enable = true;

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
  };
  programs.zsh = {
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
    THUNARX_DIRS = "$HOME/.nix-profile/lib/thunarx-3";
    XDG_SESSION_TYPE = "wayland";
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
    gtk4 = {
      theme = config.gtk.theme;
      extraConfig = {
        Settings = ''
          gtk-application-prefer-dark-theme=0
        '';
      };
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  home.username = lib.mkForce "maddev";
  home.homeDirectory = lib.mkForce "/home/maddev";

  xdg.configFile = {
    "imv/config".text = ''
      [binds]
      <Delete> = exec imv-reject "$imv_current_file" "$imv_pid"
    '';

    # Hyprland takes hyprland.lua over hyprland.conf; the tree carries this host's host.lua.
    "hypr/hyprland.lua".source = "${config.mad.hypr.tree}/hyprland.lua";
    "hypr/host.lua".source = "${config.mad.hypr.tree}/host.lua";
    "hypr/shub".source = "${config.mad.hypr.tree}/shub";

    # The hyprlang set below is dormant, kept one edit away from being the live config again.
    "hypr/hyprland.conf".source = "${shub}/hyprland/hyprland.conf";
    "hypr/defaultPrograms.conf".source = "${shub}/hyprland/defaultPrograms.conf";
    "hypr/startUpApps.conf".source = "${shub}/hyprland/startUpApps.conf";
    "hypr/Envs.conf".source = "${shub}/hyprland/Envs.conf";
    "hypr/keyBinds.conf".source = "${shub}/hyprland/keyBinds.conf";
    "hypr/windowRules.conf".source = "${shub}/hyprland/windowRules.conf";
    "hypr/workspaceRules.conf".source = "${shub}/hyprland/workspaceRules.conf";
    "hypr/hyprlock".source = "${shub}/hyprland/hyprlock";
    "hypr/hyprpaper".source = "${shub}/hyprland/hyprpaper";
    "hypr/scripts".source = "${shub}/hyprland/scripts";

    # PER FILE, not directory sources, so a host can override one file without forking the set.
    "waybar/config".source = "${shub}/waybar/config";
    "waybar/config-cava".source = "${shub}/waybar/config-cava";
    "waybar/modules".source = "${shub}/waybar/modules";
    "waybar/style.css".source = "${shub}/waybar/style.css";
    "rofi/config.rasi".source = "${shub}/rofi/config.rasi";
    "rofi/apps.rasi".source = "${shub}/rofi/apps.rasi";
    "rofi/gruvbox-material.rasi".source = "${shub}/rofi/gruvbox-material.rasi";
    "rofi/wallpapers.rasi".source = "${shub}/rofi/wallpapers.rasi";

    # Not a directory source: a class or host module drops its own list into rofi/tasks.d.
    "rofi/tasks.sh" = {
      source = "${shub}/rofi/tasks.sh";
      executable = true;
    };
    "rofi/tasks.d/10-radio.sh" = {
      source = "${shub}/rofi/tasks.d/10-radio.sh";
      executable = true;
    };
    "swaync".source = "${shub}/swaync";
    # gvfsd-http fetches swaync's https album art and needs glib-networking for TLS.
    "systemd/user/gvfs-daemon.service.d/tls.conf".text = ''
      [Service]
      Environment=GIO_EXTRA_MODULES=${pkgs.glib-networking}/lib/gio/modules
    '';
    "wlogout".source = "${shub}/wlogout";
    "fastfetch".source = "${shub}/fastfetch";
    "ghostty/config".source = "${shub}/ghostty/.config/ghostty/config";
    "ghostty/themes".source = "${shub}/ghostty/.config/ghostty/themes";
    "zsh/.zshrc".source = "${shub}/zsh/.zshrc";
    "starship.toml".source = "${vanilla}/starship/.config/starship.toml";
    "nvim".source = inputs.nvim;
  };

  home.file = {
    ".zshrc".source = "${shub}/zsh/.zshrc";
    ".tmux.conf".source = "${vanilla}/tmux/.tmux.conf";
    ".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0";
      sha256 = "18i499hhxly1r2bnqp9wssh0p1v391cxf10aydxaa7mdmrd3vqh9";
    };
  };

  # Zen's user.js is wired up in ../modules/zen.nix (imported above).

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      };
    };
  };

  home.stateVersion = "25.05";
}

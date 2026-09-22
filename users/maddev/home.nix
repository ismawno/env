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
  # Writable checkout for lazy.nvim's lock file; switch the url to move to a fork.
  nvimCheckout = {
    path = "${config.home.homeDirectory}/nvim";
    url = "https://github.com/ismawno/nvim";
  };
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
    btop # waybar sysinfo click target
    gdu
    imagemagick
    tree-sitter

    (thunar.override {
      thunarPlugins = [
        thunar-archive-plugin
        thunar-volman
      ];
    })
    tumbler
    file-roller

    gvfs

    gcc
    gnumake
    fd

    wakeonlan

    # Drop this override and waybar-hyprland-lua.patch once a waybar release with PR #5013 is in nixpkgs.
    (waybar.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./waybar-hyprland-lua.patch ];
    }))
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

  services.syncthing.enable = true;

  # TUI tools rofi would otherwise miss, each floated in its own ghostty by popup.sh.
  xdg.desktopEntries =
    let
      popup = "${config.home.homeDirectory}/.config/hypr/scripts/popup.sh";
    in
    {
      nmtui = {
        name = "Network Manager (nmtui)";
        genericName = "Network Configuration";
        exec = "${popup} 60 60 nmtui";
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

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "thunar.desktop" ];

      "x-scheme-handler/http" = [ "zen-beta.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" ];
      "text/html" = [ "zen-beta.desktop" ];
      "application/xhtml+xml" = [ "zen-beta.desktop" ];

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

      "video/mp4" = [ "mpv.desktop" ];
      "video/mkv" = [ "mpv.desktop" ];
      "video/x-matroska" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "video/quicktime" = [ "mpv.desktop" ];
      "video/x-msvideo" = [ "mpv.desktop" ];
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

  home.sessionVariables = {
    GTK_THEME = "Gruvbox-Light";
    WNO_NVIM_PATH = nvimCheckout.path;
  };
  mad.hypr.facts.env = { inherit (config.home.sessionVariables) WNO_NVIM_PATH; };

  home.activation.nvimCheckout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${lib.escapeShellArg nvimCheckout.path} ]; then
      run env GIT_TERMINAL_PROMPT=0 ${lib.getExe config.programs.git.package} clone --quiet \
        ${nvimCheckout.url} ${lib.escapeShellArg nvimCheckout.path} \
        || warnEcho "Could not clone ${nvimCheckout.url} into ${nvimCheckout.path}; the next activation retries."
    fi
  '';

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
    gtk4.theme = config.gtk.theme;
  };

  # Also sets XCURSOR_* and HYPRCURSOR_*.
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
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

    "hypr/hyprland.lua".source = "${config.mad.hypr.tree}/hyprland.lua";
    "hypr/host.lua".source = "${config.mad.hypr.tree}/host.lua";
    "hypr/shub".source = "${config.mad.hypr.tree}/shub";
    "hypr/hyprlock".source = "${shub}/hyprland/hyprlock";
    "hypr/hyprpaper".source = "${shub}/hyprland/hyprpaper";
    "hypr/scripts".source = "${shub}/hyprland/scripts";

    # PER FILE, not directory sources, so a host can override one file and a module can add to rofi/tasks.d.
    "waybar/config".source = "${shub}/waybar/config";
    "waybar/config-cava".source = "${shub}/waybar/config-cava";
    "waybar/modules".source = "${shub}/waybar/modules";
    "waybar/style.css".source = "${shub}/waybar/style.css";
    "rofi/config.rasi".source = "${shub}/rofi/config.rasi";
    "rofi/apps.rasi".source = "${shub}/rofi/apps.rasi";
    "rofi/gruvbox-material.rasi".source = "${shub}/rofi/gruvbox-material.rasi";
    "rofi/wallpapers.rasi".source = "${shub}/rofi/wallpapers.rasi";
    "rofi/tasks.sh".source = "${shub}/rofi/tasks.sh";
    "rofi/tasks.d/10-radio.sh".source = "${shub}/rofi/tasks.d/10-radio.sh";

    "swaync".source = "${shub}/swaync";
    "wlogout".source = "${shub}/wlogout";
    "fastfetch".source = "${shub}/fastfetch";
    "ghostty/config".source = "${shub}/ghostty/.config/ghostty/config";
    "ghostty/themes".source = "${shub}/ghostty/.config/ghostty/themes";
    "starship.toml".source = "${vanilla}/starship/.config/starship.toml";
    "nvim".source = inputs.nvim;

    # qt6ct paints its own light palette unless it is given one.
    "qt6ct/colors/gruvbox.conf".source = "${shub}/qt6ct/colors/gruvbox.conf";
    "qt6ct/qt6ct.conf".text = ''
      [Appearance]
      color_scheme_path=${config.xdg.configHome}/qt6ct/colors/gruvbox.conf
      custom_palette=true
      icon_theme=${config.gtk.iconTheme.name}
      standard_dialogs=default
      style=Fusion
    '';

    # gvfsd-http fetches swaync's https album art and needs glib-networking for TLS.
    "systemd/user/gvfs-daemon.service.d/tls.conf".text = ''
      [Service]
      Environment=GIO_EXTRA_MODULES=${pkgs.glib-networking}/lib/gio/modules
    '';
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

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
    };
  };

  home.stateVersion = "25.05";
}

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
    # --- CORE ---
    zoxide
    ripgrep
    fzf
    unzip
    htop
    gdu
    
    # --- GUI / HYPRLAND UTILS ---
    waybar
    hyprpaper
    hyprlock
    rofi               # UPDATED: Using 'rofi' as per your Nixpkgs version
    swaynotificationcenter 
    wlogout
    fastfetch
    hyprpicker
    
    # hyprsunset       # WARNING: This is likely not in standard nixpkgs. 
                       # Uncomment only if you are sure it exists or have an overlay.
    
    # --- MEDIA / APPS ---
    firefox
    ghostty
    mpv
    spotify
    cava
    ollama
    
    # --- DEV / TERMINAL ---
    nodejs_22
    tmux
    hwloc
    pulseaudio
    
    # --- THEME STUFF ---
    catppuccin-cursors.mochaDark 
    
    # --- CODING ---
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

  home.username = "maddev";
  home.homeDirectory = lib.mkForce "/home/maddev";

  # Mappings
  xdg.configFile = {
    # --- HYPRLAND (From Shub) ---
    "hypr".source = "${shub}/hyprland";

    # --- UI COMPONENTS (From Shub) ---
    "waybar".source = "${shub}/waybar";
    "rofi".source = "${shub}/rofi";
    "swaync".source = "${shub}/swaync";
    "wlogout".source = "${shub}/wlogout";
    "fastfetch".source = "${shub}/fastfetch";
    "kitty".source = "${shub}/kitty";

    # --- WALLPAPERS (From Shub) ---
    "backgrounds".source = "${shub}/backgrounds";

    # --- LEGACY / VANILLA CONFIGS ---
    "ghostty".source = "${vanilla}/ghostty/.config/ghostty";
    "zsh/.zshrc".source = "${vanilla}/zsh/.zshrc";
    "starship.toml".source = "${vanilla}/starship/.config/starship.toml";
    
    # --- NVIM ---
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

  home.stateVersion = "25.05";
}

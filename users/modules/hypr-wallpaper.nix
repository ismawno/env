# The wallpaper as tracked data: one pinned url every host fetches, plus the picker that rewrites it.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mad.hypr.wallpaper;
  shub = ../../dotfiles/shub;
  tool = ../../dotfiles/shub/hyprland-lua/tools/wallpaper-pick.sh;

  selection = import cfg.selectionFile;
  chosen = selection ? url;

  picture = pkgs.fetchurl {
    inherit (selection) url hash;
    # The repo's file names carry spaces, commas and Cyrillic; a store name takes none of them.
    name = lib.strings.sanitizeDerivationName "wallpaper-${selection.name}";
  };

  # hyprpaper.conf names one stable path, so the plain dotfile stays valid away from Nix.
  backgrounds = pkgs.runCommand "backgrounds-with-current" { } ''
    cp -r ${shub}/backgrounds $out
    chmod u+w $out
    ln -s ${if chosen then "${picture}" else "1.png"} $out/current
  '';

  picker = pkgs.writeShellApplication {
    name = "wallpaper-pick";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      findutils
      git
      hyprpaper
      imagemagick
      jq
      libnotify
      procps
      rofi
      util-linux
    ];
    text = ''
      export MAD_WP_ENV=${lib.escapeShellArg cfg.envDir}
      export MAD_WP_SELECTION=${lib.escapeShellArg "${cfg.envDir}/${cfg.repoPath}"}
      export MAD_WP_REPO_PATH=${lib.escapeShellArg cfg.repoPath}
      export MAD_WP_SLUG=${lib.escapeShellArg cfg.repo}
      export MAD_WP_PREFIX=${lib.escapeShellArg cfg.repoPrefix}
      export MAD_WP_STABLE=${lib.escapeShellArg "${config.xdg.configHome}/backgrounds/current"}
      export MAD_WP_CONF=${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprpaper/hyprpaper.conf"}
      # These two are the test seams: a run may aim the picker at another collection or thumbnail source.
      export MAD_WP_COLLECTION=''${MAD_WP_COLLECTION:-${lib.escapeShellArg cfg.collectionDir}}
      export MAD_WP_THUMB_BASE=''${MAD_WP_THUMB_BASE:-${lib.escapeShellArg cfg.thumbnailBase}}
      exec ${pkgs.bash}/bin/bash ${tool} "$@"
    '';
  };
in
{
  options.mad.hypr.wallpaper = {
    selectionFile = lib.mkOption {
      type = lib.types.path;
      default = ../maddev/wallpaper.nix;
      description = "The tracked Nix data file holding the chosen picture; an empty set there keeps the stock background.";
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "users/maddev/wallpaper.nix";
      description = "Where selectionFile lives inside envDir; that working copy is what the picker rewrites.";
    };

    envDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/env";
      description = "The flake checkout the picker writes into and then activates.";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "Mars-Wave/caelestia-wallpapers-AMOLED";
      description = "The public GitHub repository the pictures are pinned from.";
    };

    repoPrefix = lib.mkOption {
      type = lib.types.str;
      default = "wallpapers";
      description = "The directory inside that repository the picture names are relative to.";
    };

    collectionDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Pictures/Wallpapers";
      description = "The same pictures on disk; a host without them browses the repo's thumbnails instead.";
    };

    thumbnailBase = lib.mkOption {
      type = lib.types.str;
      default = "https://raw.githubusercontent.com/${cfg.repo}/main";
      description = "Where the picker reads thumbnails/index.tsv and the small jpegs beside it, for a host with no local collection. Plain git files, so browsing costs no Git LFS bandwidth.";
    };
  };

  config = {
    home.packages = [ picker ];

    # home.nix cannot link the whole directory any more: "current" has to be added to it.
    xdg.configFile."backgrounds".source = backgrounds;

    xdg.configFile."rofi/tasks.d/30-wallpaper.tsv".text = "> Change Wallpaper\twallpaper-pick\n";

    mad.hypr.facts = lib.optionalAttrs (selection ? color) { background_color = selection.color; };
  };
}

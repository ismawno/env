# The wallpaper as tracked data: one pinned url every host fetches, plus the picker that rewrites it.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  shub = ../../dotfiles/shub;
  envDir = "${config.home.homeDirectory}/env";
  repo = "Mars-Wave/caelestia-wallpapers-AMOLED";
  # An empty set in this file keeps the stock background.
  repoPath = "users/maddev/wallpaper.nix";

  selection = import (../.. + "/${repoPath}");

  picture = pkgs.fetchurl {
    inherit (selection) url hash;
    # The repo's file names carry spaces, commas and Cyrillic; a store name takes none of them.
    name = lib.strings.sanitizeDerivationName "wallpaper-${selection.name}";
  };

  # hyprpaper.conf names one stable path, so the plain dotfile stays valid away from Nix.
  backgrounds = pkgs.runCommand "backgrounds-with-current" { } ''
    cp -r ${shub}/backgrounds $out
    chmod u+w $out
    ln -sfn ${if selection ? url then "${picture}" else "1.png"} $out/current
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
      export MAD_WP_ENV=${lib.escapeShellArg envDir}
      export MAD_WP_SELECTION=${lib.escapeShellArg "${envDir}/${repoPath}"}
      export MAD_WP_REPO_PATH=${lib.escapeShellArg repoPath}
      export MAD_WP_SLUG=${lib.escapeShellArg repo}
      export MAD_WP_PREFIX=wallpapers
      export MAD_WP_STABLE=${lib.escapeShellArg "${config.xdg.configHome}/backgrounds/current"}
      export MAD_WP_CONF=${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprpaper/hyprpaper.conf"}
      # The test seams: a run may aim the picker at another collection, thumbnail source or home-manager.
      export MAD_WP_COLLECTION=''${MAD_WP_COLLECTION:-${lib.escapeShellArg "${config.home.homeDirectory}/Pictures/Wallpapers"}}
      export MAD_WP_THUMB_BASE=''${MAD_WP_THUMB_BASE:-${lib.escapeShellArg "https://raw.githubusercontent.com/${repo}/main"}}
      export MAD_WP_HM=''${MAD_WP_HM:-home-manager}
      exec ${pkgs.bash}/bin/bash ${../../dotfiles/shub/hyprland-lua/tools/wallpaper-pick.sh} "$@"
    '';
  };
in
{
  home.packages = [ picker ];

  xdg.configFile."backgrounds".source = backgrounds;

  xdg.configFile."rofi/tasks.d/30-wallpaper.tsv".text = "> Change Wallpaper\twallpaper-pick\n";

  mad.hypr.facts = lib.optionalAttrs (selection ? color) { background_color = selection.color; };
}

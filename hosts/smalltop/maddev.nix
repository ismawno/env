{
  pkgs,
  lib,
  ...
}:

let
  shubGhostty = ../../dotfiles/shub/ghostty/.config/ghostty/config;
  shubWaybarCss = ../../dotfiles/shub/waybar/style.css;

  # SCALE 2, NOT 1.5: at 1.5 Ghostty's cell advance is 17.25px instead of 23px and GTK3 clients get downsampled.
  panel = {
    output = "eDP-1";
    mode = "2880x1800@120";
    position = "0x0";
    scale = 2;
  };

  # smalltop is 2880x1800 at scale 2 (a 1440x900 logical desktop). Overrides are
  # APPENDED to the shared dotfiles, which stay the single source of truth for bigsys.
  ghosttyOverrides = pkgs.writeText "ghostty-smalltop-overrides.conf" ''

    # Ghostty takes the LAST duplicate key; at scale 2 an integral em needs a multiple of 0.375.
    font-size = 12

  '';

  waybarOverrides = pkgs.writeText "waybar-smalltop-overrides.css" ''

    /* HiDPI: paddings are round(original * 0.75). A percentage font-size compounds down the tree, do not add one. */

    tooltip label {
      padding: 8px;
    }

    #clock,
    #mpris,
    #pulseaudio,
    #workspaces,
    #custom-conn,
    #custom-modelight,
    #custom-sysinfo,
    #custom-swaync {
      padding-top: 2px;
      padding-bottom: 2px;
      padding-left: 5px;
      padding-right: 5px;
    }

    #window {
      padding-top: 2px;
      padding-bottom: 2px;
      padding-left: 5px;
      padding-right: 5px;
    }

    #workspaces button {
      padding-left: 5px;
      padding-right: 5px;
    }
  '';
in
{
  imports = [
    ../../users/modules/hypr-laptop.nix
  ];

  # System syncthing only here; two daemons fight over the database lock.
  services.syncthing.enable = lib.mkForce false;

  mad.hypr = {
    monitors = [
      panel
      {
        output = "desc:AOC U27B3A ZXLQ8HA002427";
        mode = "3840x2160@60";
        position = "0x-1080";
        scale = 2;
      }
      # Explicit, not "auto": Hyprland moves an auto monitor when the panel leaves the layout but leaves waybar and hyprpaper at the old origin. 1440 is the panel's logical width.
      {
        output = "";
        mode = "3840x2160@60";
        position = "1440x0";
        scale = 1;
      }
    ];

    lid = {
      switch = "Lid Switch";
      output = panel.output;
      state = "/proc/acpi/button/lid/LID0/state";
    };
  };

  # mkForce: home.nix wires these per file so a host can replace one without forking the directory.
  xdg.configFile."ghostty/config".source = lib.mkForce (
    pkgs.concatText "ghostty-config-smalltop" [
      shubGhostty
      ghosttyOverrides
    ]
  );

  xdg.configFile."waybar/style.css".source = lib.mkForce (
    pkgs.concatText "waybar-style-smalltop.css" [
      shubWaybarCss
      waybarOverrides
    ]
  );
}

{
  config,
  pkgs,
  lib,
  ...
}:

let
  shubGhostty = ../../dotfiles/shub/ghostty/.config/ghostty/config;
  shubWaybarCss = ../../dotfiles/shub/waybar/style.css;

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
    # SCALE 2, NOT 1.5, for the panel in there: at 1.5 Ghostty's cell advance is 17.25px instead of 23px and GTK3 clients get downsampled.
    displays = {
      layoutFile = ./monitors.lua;
      repoPath = "hosts/smalltop/monitors.lua";
    };

    lid = {
      switch = "Lid Switch";
      output = "eDP-1";
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

  # qt6ct paints its own light palette unless it is given one.
  xdg.configFile."qt6ct/colors/gruvbox.conf".source = ../../dotfiles/shub/qt6ct/colors/gruvbox.conf;
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    color_scheme_path=${config.xdg.configHome}/qt6ct/colors/gruvbox.conf
    custom_palette=true
    icon_theme=Gruvbox-Plus-Dark
    standard_dialogs=default
    style=Fusion
  '';
}

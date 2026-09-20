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
  panelRule = "${panel.output},${panel.mode},${panel.position},${toString panel.scale}";

  # Lid: drop the panel from the layout if another display exists, else only blank it (Hyprland needs one monitor).
  lidScript = pkgs.writeShellScript "smalltop-lid" ''
    close() {
      if [ "$(hyprctl monitors | grep -c "^Monitor")" -gt 1 ]; then
        hyprctl keyword monitor "${panel.output}, disable"
      else
        hyprctl dispatch dpms off "${panel.output}"
      fi
    }
    case "$1" in
      close) close ;;
      open) hyprctl keyword monitor "${panelRule}"; hyprctl dispatch dpms on "${panel.output}" ;;
      sync) grep -q closed /proc/acpi/button/lid/*/state && close ;;
    esac
  '';

  # smalltop is 2880x1800 at scale 2 (a 1440x900 logical desktop). Overrides are
  # APPENDED to the shared dotfiles, which stay the single source of truth for bigsys.
  ghosttyOverrides = pkgs.writeText "ghostty-smalltop-overrides.conf" ''

    # HiDPI overrides, appended; Ghostty takes the LAST duplicate key. At scale 2 an
    # integral em needs a point size that is a multiple of 0.375 -- retune only to those.
    font-size = 12

    # No background-opacity or alpha-blending overrides. `linear` fixes light-on-dark
    # thinning but was rejected on sight as fuzzier -- do not re-apply unasked.
  '';

  waybarOverrides = pkgs.writeText "waybar-smalltop-overrides.css" ''

    /* smalltop HiDPI overrides, appended -- see hosts/smalltop/maddev.nix.
       Paddings are round(original * 0.75). NO font-size override: `* { font-size:
       75% }` was tried and is wrong -- a percentage font-size compounds down the
       tree, and Waybar's CSS sizes do not scale with the compositor the way
       Ghostty's points do. Verified at scale 2 with the paddings alone. */

    tooltip label {
      padding: 8px;
    }

    #custom-lumi,
    #custom-cava,
    #clock,
    #cpu,
    #memory,
    #mpris,
    #network,
    #pulseaudio,
    #temperature,
    #workspaces,
    #custom-menu,
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
    ../../users/modules/pkgs-unstable.nix
    ../../users/modules/hypr-laptop.nix
  ];

  # System syncthing only -- the home-manager user unit is right for bigsys. Both
  # running means the loser cannot take the database lock and every switch fails.
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
      {
        output = "";
        mode = "3840x2160@60";
        position = "auto";
        scale = 1;
      }
    ];

    lid = {
      switch = "Lid Switch";
      script = "${lidScript}";
    };
  };

  # mkForce because users/maddev/home.nix defines these too; that file wires ghostty
  # and waybar PER FILE so a host can replace one file without forking the directory.
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

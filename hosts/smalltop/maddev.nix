{
  pkgs,
  lib,
  ...
}:

let
  shubGhostty = ../../dotfiles/shub/ghostty/.config/ghostty/config;
  shubWaybarCss = ../../dotfiles/shub/waybar/style.css;
  shubHyprland = ../../dotfiles/shub/hyprland/hyprland.conf;

  # Hyprland's `decoration {}` is GLOBAL (no per-monitor block), so these cannot live
  # in the shared hyprland.conf without also restyling bigsys. Appended; later wins.
  hyprlandOverrides = pkgs.writeText "hyprland-smalltop-overrides.conf" ''

    # smalltop overrides (appended -- see hosts/smalltop/maddev.nix)
    decoration {
        # was 0.7, which dropped inactive-window text contrast 11.34:1 -> 5.70:1.
        inactive_opacity = 1

        blur {
            # was 3 passes: resamples what is behind the window, which is the
            # smearing this whole change set exists to remove.
            enabled = no
        }
    }

    general {
        # Explicit 0deg: a bare rgb() can be interpolated as a gradient endpoint.
        col.active_border = rgb(EBDBB2) 0deg
    }
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
  imports = [ ../../users/modules/pkgs-unstable.nix ];

  # System syncthing only -- the home-manager user unit is right for bigsys. Both
  # running means the loser cannot take the database lock and every switch fails.
  services.syncthing.enable = lib.mkForce false;

  # mkForce because users/maddev/home.nix defines these too; that file wires ghostty
  # and waybar PER FILE so a host can replace one file without forking the directory.
  xdg.configFile."hypr/hyprland.conf".source = lib.mkForce (
    pkgs.concatText "hyprland-conf-smalltop" [
      shubHyprland
      hyprlandOverrides
    ]
  );

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

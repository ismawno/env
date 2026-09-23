{
  pkgs,
  lib,
  ...
}:

let
  # smalltop is 2880x1800 at scale 2; its overrides go after the shared dotfile, which stays bigsys's source of truth.
  append =
    name: shared: overrides:
    lib.mkForce (
      pkgs.concatText name [
        (../../dotfiles/shub + "/${shared}")
        (pkgs.writeText "${name}-overrides" overrides)
      ]
    );
in
{
  imports = [ ../../users/modules/hypr-laptop.nix ];

  # System syncthing only here; two daemons fight over the database lock.
  services.syncthing.enable = lib.mkForce false;

  mad.hypr = {
    # Keep the panel at SCALE 2, NOT 1.5, in monitors.lua: at 1.5 Ghostty's cell advance is 17.25px instead of 23px and GTK3 clients get downsampled.
    displays.repoPath = "hosts/smalltop/monitors.lua";

    keyring = true;

    lid = {
      switch = "Lid Switch";
      output = "eDP-1";
      state = "/proc/acpi/button/lid/LID0/state";
    };
  };

  xdg.configFile = {
    "ghostty/config".source = append "ghostty-config-smalltop" "ghostty/.config/ghostty/config" ''

      # Ghostty takes the LAST duplicate key; at scale 2 an integral em needs a multiple of 0.375.
      font-size = 12

    '';

    "waybar/style.css".source = append "waybar-style-smalltop.css" "waybar/style.css" ''

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
      #custom-swaync,
      #window {
        padding: 2px 5px;
      }

      #workspaces button {
        padding: 0px 5px;
      }
    '';
  };
}

# Laptop profile for the shared Hyprland Lua tree: shub/laptop.lua wants the lid switch, the panel it drives and the ACPI state file.
{ config, lib, ... }:

{
  imports = [
    ./hypr-host.nix
    ./hypr-laptop-displays.nix
  ];

  options.mad.hypr.lid = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    example = {
      switch = "Lid Switch";
      output = "eDP-1";
      state = "/proc/acpi/button/lid/LID0/state";
    };
    description = "Lid switch name, the panel it drives, and the ACPI state file its handlers read.";
  };

  config.mad.hypr.facts = {
    kind = "laptop";
    inherit (config.mad.hypr) lid;
  };
}

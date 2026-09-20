# Laptop profile for the shared Hyprland Lua tree: shub/laptop.lua wants the lid switch and the script it calls.
{ config, lib, ... }:

{
  imports = [ ./hypr-host.nix ];

  options.mad.hypr.lid = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    example = {
      switch = "Lid Switch";
      script = "/run/current-system/sw/bin/lid";
    };
    description = "Lid switch name and the script its close, open and sync binds call.";
  };

  config.mad.hypr.facts = {
    kind = "laptop";
    inherit (config.mad.hypr) lid;
  };
}

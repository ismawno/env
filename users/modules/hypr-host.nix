# The per-machine half of the Hyprland config: one host.lua that the shared Lua tree reads.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mad.hypr;
  shared = ../../dotfiles/shub/hyprland-lua;
  hostLua = pkgs.writeText "hypr-host.lua" ''
    return ${lib.generators.toLua { } cfg.facts}
  '';
in
{
  imports = [ ./hypr-wallpaper.nix ];

  options.mad.hypr = {
    monitors = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [
        {
          output = "";
          mode = "3840x2160@60";
          position = "auto";
          scale = 1;
        }
      ];
      description = "hl.monitor specs, applied in the order given. A laptop wants an explicit position on every monitor: Hyprland does not re-arrange layer surfaces for a monitor it moves, so an auto-positioned one strands waybar and hyprpaper when the panel leaves the layout.";
    };

    monitorsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "A tracked, pure-data Lua file of hl.monitor specs, installed beside host.lua and read instead of mad.hypr.monitors.";
    };

    facts = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      description = "Everything rendered into host.lua; hypr-laptop.nix or hypr-desktop.nix adds the profile, and facts.programs replaces default programs.";
    };

    tree = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      # Hyprland resolves require() next to the real config file, so host.lua must share the entry point's store directory.
      default = pkgs.runCommand "hypr-lua" { } ''
        mkdir -p $out
        cp ${shared}/hyprland.lua $out/hyprland.lua
        cp -r ${shared}/shub $out/shub
        cp ${hostLua} $out/host.lua
        ${lib.optionalString (cfg.monitorsFile != null) "cp ${cfg.monitorsFile} $out/monitors.lua"}
      '';
      description = "The shared Lua tree with this host's host.lua rendered beside it.";
    };
  };

  config.mad.hypr.facts = {
    inherit (cfg) monitors;
    monitors_file = cfg.monitorsFile != null;
    polkit_agent = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
  };
}

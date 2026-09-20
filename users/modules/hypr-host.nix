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
      description = "hl.monitor specs, applied in the order given.";
    };

    programs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Host-only replacements for the default programs.";
    };

    facts = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      description = "Everything rendered into host.lua; hypr-laptop.nix or hypr-desktop.nix adds the profile.";
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
      '';
      description = "The shared Lua tree with this host's host.lua rendered beside it.";
    };
  };

  config.mad.hypr.facts = {
    inherit (cfg) monitors programs;
    polkit_agent = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
  };
}

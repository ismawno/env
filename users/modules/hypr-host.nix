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
  facts = {
    inherit (cfg)
      monitors
      blur
      lid
      programs
      ;
    inactive_opacity = cfg.inactiveOpacity;
  };
  hostLua = pkgs.writeText "hypr-host.lua" ''
    return ${lib.generators.toLua { } facts}
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

    inactiveOpacity = lib.mkOption {
      type = lib.types.numbers.between 0.0 1.0;
      default = 0.7;
      description = "decoration.inactive_opacity for this host.";
    };

    blur = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "decoration.blur.enabled for this host.";
    };

    lid = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
      default = null;
      example = {
        switch = "Lid Switch";
        script = "/run/current-system/sw/bin/lid";
      };
      description = "Lid switch name and the script its close, open and sync binds call.";
    };

    programs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Host-only replacements for the default programs.";
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
}

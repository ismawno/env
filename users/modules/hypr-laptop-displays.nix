# The laptop's screen list as tracked data, plus the saver that rewrites it from the live session.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mad.hypr.displays;
  tool = ../../dotfiles/shub/hyprland-lua/tools/display-layout-save.lua;

  saver = pkgs.writeShellScriptBin "display-layout-save" ''
    export MAD_DISPLAYS_JQ=${pkgs.jq}/bin/jq
    export MAD_DISPLAYS_ENV=${lib.escapeShellArg cfg.envDir}
    export MAD_DISPLAYS_REPO_PATH=${lib.escapeShellArg cfg.repoPath}
    export MAD_DISPLAYS_FILE=${lib.escapeShellArg "${cfg.envDir}/${cfg.repoPath}"}
    export MAD_DISPLAYS_PANEL=${lib.escapeShellArg config.mad.hypr.lid.output}
    exec ${pkgs.luajit}/bin/luajit ${tool} "$@"
  '';
in
{
  options.mad.hypr.displays = {
    layoutFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "The host's monitors.lua. Setting it moves the screen list out of mad.hypr.monitors and turns the saver on.";
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Where layoutFile lives inside envDir; that working copy is what the saver rewrites.";
    };

    envDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/env";
      description = "The flake checkout the saver writes into and then activates.";
    };

    catchall = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.str lib.types.number);
      default = {
        mode = "3840x2160@60";
        scale = 1;
      };
      description = "Mode and scale for a screen with no entry of its own; the shared Lua puts it right of the panel.";
    };
  };

  config = lib.mkIf (cfg.layoutFile != null) {
    mad.hypr = {
      monitorsFile = cfg.layoutFile;
      monitors = [ ];
      facts.catchall = cfg.catchall;
    };

    home.packages = [ saver ];

    # Beside host.lua in the tree is not enough: Hyprland requires it from ~/.config/hypr, which home.nix fills file by file.
    xdg.configFile."hypr/monitors.lua".source = "${config.mad.hypr.tree}/monitors.lua";

    xdg.configFile."rofi/tasks.d/20-displays.tsv".text =
      "> Display Settings\twdisplays\n> Save Display Layout to Nix Env\tdisplay-layout-save\n";
  };
}

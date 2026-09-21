# The laptop's screen list as tracked data, plus the saver that rewrites it from the live session.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.mad.hypr.displays) repoPath;
  envDir = "${config.home.homeDirectory}/env";

  saver = pkgs.writeShellScriptBin "display-layout-save" ''
    export MAD_DISPLAYS_JQ=${pkgs.jq}/bin/jq
    export MAD_DISPLAYS_ENV=${lib.escapeShellArg envDir}
    export MAD_DISPLAYS_REPO_PATH=${lib.escapeShellArg repoPath}
    export MAD_DISPLAYS_FILE=${lib.escapeShellArg "${envDir}/${repoPath}"}
    export MAD_DISPLAYS_PANEL=${lib.escapeShellArg config.mad.hypr.lid.output}
    exec ${pkgs.luajit}/bin/luajit ${../../dotfiles/shub/hyprland-lua/tools/display-layout-save.lua} "$@"
  '';
in
{
  options.mad.hypr.displays.repoPath = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "hosts/smalltop/monitors.lua";
    description = "The host's monitors.lua inside ~/env. Setting it moves the screen list out of mad.hypr.monitors and turns on the saver, which rewrites that working copy.";
  };

  config = lib.mkIf (repoPath != null) {
    mad.hypr = {
      monitorsFile = ../.. + "/${repoPath}";
      monitors = [ ];
      # A screen with no entry of its own; the shared Lua puts it right of the panel.
      facts.catchall = {
        mode = "3840x2160@60";
        scale = 1;
      };
    };

    home.packages = [ saver ];

    # Beside host.lua in the tree is not enough: Hyprland requires it from ~/.config/hypr, which home.nix fills file by file.
    xdg.configFile."hypr/monitors.lua".source = "${config.mad.hypr.tree}/monitors.lua";

    xdg.configFile."rofi/tasks.d/20-displays.tsv".text =
      "> Display Settings\twdisplays\n> Save Display Layout to Nix Env\tdisplay-layout-save\n";
  };
}

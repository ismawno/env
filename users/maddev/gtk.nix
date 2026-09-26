# GTK look and modules, exported to shells, the Hyprland session and systemd user services alike.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mad.gtk;
  # The theme's GTK 3 sheet carries GTK 4's border-spacing, which every GTK 3 process reported as a parse error.
  theme = pkgs.gruvbox-gtk-theme.overrideAttrs (old: {
    postPatch = old.postPatch + ''
      substituteInPlace themes/src/sass/gtk/_common-3.0.scss \
        --replace-fail $'\t\tborder-spacing: $space-size;\n' ""
    '';
    postInstall = (old.postInstall or "") + ''
      if grep -rn border-spacing $out/share/themes/*/gtk-3.0; then
        echo "a GTK 3 sheet still declares border-spacing" >&2
        exit 1
      fi
    '';
  });
  modules = pkgs.runCommand "gtk3-modules" { } ''
    mkdir -p $out/lib/gtk-3.0/modules
    ${lib.concatStrings (
      lib.mapAttrsToList (name: package: ''
        so=${package}/lib/gtk-3.0/modules/lib${name}.so
        [ -e "$so" ] || { echo "$so does not exist" >&2; exit 1; }
        ln -s "$so" $out/lib/gtk-3.0/modules/
      '') cfg.modules
    )}
  '';
  env = {
    GTK_THEME = config.gtk.theme.name;
  }
  // lib.optionalAttrs (cfg.modules != { }) {
    GTK_MODULES = lib.concatStringsSep ":" (lib.attrNames cfg.modules);
  };
in
{
  options.mad.gtk.modules = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    # Empty: canberra would add dialog sounds, xapp and appmenu have nothing to talk to under Hyprland.
    default = { };
    example = lib.literalExpression "{ canberra-gtk-module = pkgs.libcanberra-gtk3; }";
    description = "GTK 3 modules for GTK_MODULES, keyed by module name, each from the package whose lib/gtk-3.0/modules holds lib<name>.so. The build fails on a name without that file; the file is linked into the profile, whose lib/gtk-3.0 NixOS puts on GTK_PATH. GTK 4 dropped modules.";
  };

  config = {
    gtk = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };
      theme = {
        name = "Gruvbox-Light";
        package = theme;
      };
      gtk4.theme = config.gtk.theme;
      colorScheme = "light";
      iconTheme = {
        name = "Gruvbox-Plus-Dark";
        package = pkgs.callPackage ./gruvbox-plus-icons.nix { };
      };
    };

    # Also sets XCURSOR_*, HYPRCURSOR_* and the GTK cursor theme.
    home.pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      hyprcursor.enable = true;
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    home.packages = [
      # Gruvbox Plus names breeze-dark as its parent; the old icon pack carried its own copy of its parent.
      pkgs.kdePackages.breeze-icons
    ]
    ++ lib.optional (cfg.modules != { }) modules;

    home.sessionVariables = env;
    systemd.user.sessionVariables = env;
    mad.hypr.facts.env = env;
  };
}

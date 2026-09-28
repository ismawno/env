# The desktop look, switched at runtime by look-pick: every valid entry is a prebuilt bundle, and ~/.local/state/look points each kind at one of them.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mad.look;
  stateDir = "${config.xdg.stateHome}/look";
  dataDir = "${config.xdg.dataHome}/look";
  state = path: config.lib.file.mkOutOfStoreSymlink "${stateDir}/${path}";
  slug = name: lib.toLower (lib.replaceStrings [ " " ] [ "-" ] name);

  themes = import ./look/themes.nix { inherit lib pkgs; };
  fonts = import ./look/fonts.nix { inherit lib pkgs; };
  icons = pkgs.callPackage ./gruvbox-plus-icons.nix { };

  # GTK 3 has no border-spacing, yet several sheets carry GTK 4's, and every GTK 3 process printed a parse error for it.
  nativeGtk = pkgs.runCommand "look-gtk-themes" { } ''
    ${lib.concatMapStrings (
      theme:
      lib.optionalString (theme.gtk.package != null) ''
        src=${theme.gtk.package}/share/themes/${theme.gtk.name}
        dst=$out/share/themes/${theme.gtk.name}
        [ -d "$src" ] || { echo "$src does not exist" >&2; exit 1; }
        mkdir -p "$dst/gtk-3.0"
        for entry in "$src"/*; do
          [ "''${entry##*/}" = gtk-3.0 ] || ln -s "$entry" "$dst/"
        done
        for entry in "$src"/gtk-3.0/*; do
          case $entry in
            *.css) sed -E 's/border-spacing:[^;}]*;?//g' "$entry" >"$dst/gtk-3.0/''${entry##*/}" ;;
            *) ln -s "$entry" "$dst/gtk-3.0/" ;;
          esac
        done
      ''
    ) themes}
    if grep -l border-spacing $out/share/themes/*/gtk-3.0/*.css; then
      echo "a GTK 3 sheet still declares border-spacing" >&2
      exit 1
    fi
  '';

  # Every Ghostty theme at once, since which of them pass is only known once their palettes are read; out holds the bundles, gtk the generated GTK themes.
  themeBundles = pkgs.runCommand "look-theme-bundles" {
    outputs = [
      "out"
      "gtk"
    ];
    nativeBuildInputs = [ pkgs.imagemagick ];
    ghosttyThemes = "${pkgs.ghostty}/share/ghostty/themes";
    adwaita = "${pkgs.adw-gtk3}/share/themes";
    iconsDark = "${icons}/share/icons/Gruvbox-Plus-Dark";
    iconsLight = "${icons}/share/icons/Gruvbox-Plus-Light";
    nativeThemes = pkgs.writeText "look-native-themes.tsv" (
      lib.concatMapStrings (
        theme:
        lib.concatStringsSep "\t" [
          theme.name
          theme.gtk.name
          (lib.optionalString (theme.gtk.package != null) "${nativeGtk}/share/themes/${theme.gtk.name}")
          (toString (lib.mapAttrsToList (role: color: "${role}=${color}") (theme.roles or { })))
        ]
        + "\n"
      ) themes
    );
    bundleScript = ./look/theme-bundle.sh;
  } "bash ${./look/themes.sh}";

  fontBundle =
    font:
    pkgs.runCommand "look-font-${slug font.name}" {
      nativeBuildInputs = [
        pkgs.fontconfig
        pkgs.imagemagick
      ];
      lookName = font.name;
      inherit (font) family mono;
      features = font.features or "";
      # The UI size of every pick, in points: GTK, dconf and Qt alike.
      size = "11";
      FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ font.package ]; };
    } "bash ${./look/font-bundle.sh}";

  fontBundles =
    let
      sorted = lib.sort (a: b: lib.toLower a.name < lib.toLower b.name) fonts;
      slugs = map (font: slug font.name) fonts;
    in
    assert lib.assertMsg (lib.allUnique slugs) "look: two fonts share a slug";
    pkgs.runCommand "look-font-bundles" { } ''
      mkdir $out
      ${lib.concatMapStrings (font: "ln -s ${fontBundle font} $out/${slug font.name}\n") fonts}
      printf '%s' ${
        lib.escapeShellArg (lib.concatMapStrings (font: "${slug font.name}\t${font.name}\n") sorted)
      } >$out/index.tsv
    '';

  # The folder look-pick reads a kind from; a default this build lacks fails here, before any switch.
  data =
    kind: bundles:
    pkgs.runCommand "look-${kind}s"
      {
        slug = cfg.${kind};
        message = "mad.look.${kind} is \"${cfg.${kind}}\", which this build has not";
      }
      ''
        awk -F '\t' -v slug="$slug" '$1 == slug { found = 1 } END { exit !found }' ${bundles}/index.tsv ||
          { echo "$message" >&2; exit 1; }
        ln -s ${bundles} $out
      '';

  kinds = {
    font = fontBundles;
    theme = themeBundles;
  };

  picker = pkgs.writeShellApplication {
    name = "look-pick";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      findutils
      gawk
      gnugrep
      gnused
      libnotify
      procps
      rofi
      swaynotificationcenter
      util-linux
    ];
    text = ''
      export MAD_LOOK_KINDS=${lib.escapeShellArg (toString (lib.attrNames kinds))}
      export MAD_LOOK_DEFAULTS=${
        lib.escapeShellArg (toString (lib.mapAttrsToList (kind: _: "${kind}=${cfg.${kind}}") kinds))
      }
      export MAD_LOOK_GTK3_BASE=${
        pkgs.writeText "look-gtk3.ini" config.xdg.configFile."gtk-3.0/settings.ini".text
      }
      export MAD_LOOK_GTK4_BASE=${
        pkgs.writeText "look-gtk4.ini" config.xdg.configFile."gtk-4.0/settings.ini".text
      }
      export MAD_LOOK_QT6CT_BASE=${pkgs.writeText "look-qt6ct.conf" ''
        [Appearance]
        custom_palette=true
        standard_dialogs=default
        style=Fusion
      ''}
      # The test seams: a run may aim the picker at a scratch home.
      export MAD_LOOK_DATA=''${MAD_LOOK_DATA:-${lib.escapeShellArg dataDir}}
      export MAD_LOOK_STATE=''${MAD_LOOK_STATE:-${lib.escapeShellArg stateDir}}
      export MAD_LOOK_QT6CT=''${MAD_LOOK_QT6CT:-${lib.escapeShellArg "${config.xdg.configHome}/qt6ct/qt6ct.conf"}}
      exec ${pkgs.bash}/bin/bash ${../../dotfiles/shub/hyprland-lua/tools/look-pick.sh} "$@"
    '';
  };
in
{
  options.mad.look = {
    theme = lib.mkOption {
      type = lib.types.str;
      default = "gruvbox-dark";
      description = "The theme, by slug, a fresh state starts from, and the one look-pick --reset goes back to; the build fails on one that no bundle has. The pick itself lives in ~/.local/state/look, so no rebuild ever undoes it.";
    };

    font = lib.mkOption {
      type = lib.types.enum (map (font: slug font.name) fonts);
      default = "fira-code";
      description = "The font of Ghostty, GTK, Qt, the bar, the panels, the menus and the lock screen a fresh state starts from, and the one look-pick --reset goes back to.";
    };
  };

  config = {
    home.packages = [
      picker
      nativeGtk
      themeBundles.gtk
      icons
      pkgs.nerd-fonts.symbols-only
    ]
    ++ map (font: font.package) fonts;

    xdg.dataFile = lib.mapAttrs' (
      kind: bundles: lib.nameValuePair "look/${kind}s" { source = data kind bundles; }
    ) kinds;

    xdg.configFile = {
      "ghostty/look-theme".source = state "theme/ghostty";
      "ghostty/look-font".source = state "font/ghostty";
      "fontconfig/conf.d/60-look-monospace.conf".source = state "font/fontconfig.conf";
      "waybar/look.css".source = state "theme/gtk3.css";
      "waybar/look-font.css".source = state "font/gtk.css";
      "waybar/look.json".source = state "theme/waybar.json";
      "wlogout/look.css".source = state "theme/gtk3.css";
      "wlogout/look-font.css".source = state "font/gtk.css";
      "swaync/look.css".source = state "theme/swaync.css";
      "swaync/look-font.css".source = state "font/swaync.css";
      "rofi/look.rasi".source = state "theme/rofi.rasi";
      "rofi/look-font.rasi".source = state "font/rofi.rasi";
      "hypr/look.lua".source = state "theme/hypr.lua";
      "gtk-4.0/gtk.css".source = state "theme/gtk4.css";
      "gtk-3.0/settings.ini".source = lib.mkForce (state "gtk3.ini");
      "gtk-4.0/settings.ini".source = lib.mkForce (state "gtk4.ini");
      "rofi/tasks.d/40-look.tsv".text =
        "> Change Font\tlook-pick font\n> Change Theme\tlook-pick theme\n";
    };

    # After dconfSettings, which resets the interface keys it no longer sets; a boot-time activation has no session bus of its own.
    home.activation.look = lib.hm.dag.entryAfter [ "linkGeneration" "dconfSettings" ] ''
      lookBus=""
      [[ -v DBUS_SESSION_BUS_ADDRESS ]] ||
        lookBus="${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon"
      run env MAD_LOOK_DCONF_WRAP="$lookBus" ${lib.getExe picker} --no-live --apply ||
        warnEcho "look-pick could not apply the saved look; look-pick --apply retries"
    '';
  };
}

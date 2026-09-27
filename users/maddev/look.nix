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
  icons = pkgs.callPackage ./gruvbox-plus-icons.nix { };

  # GTK 3 has no border-spacing, yet several sheets carry GTK 4's, and every GTK 3 process printed a parse error for it.
  gtkThemes = pkgs.runCommand "look-gtk-themes" { } ''
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

  themeBundle =
    theme:
    pkgs.runCommand "look-theme-${slug theme.name}" {
      nativeBuildInputs = [ pkgs.imagemagick ];
      lookName = theme.name;
      ghosttyTheme = "${pkgs.ghostty}/share/ghostty/themes/${theme.name}";
      gtkName = theme.gtk.name;
      gtkDir = lib.optionalString (
        theme.gtk.package != null
      ) "${gtkThemes}/share/themes/${theme.gtk.name}";
      iconsDark = "${icons}/share/icons/Gruvbox-Plus-Dark";
      iconsLight = "${icons}/share/icons/Gruvbox-Plus-Light";
      roles = toString (lib.mapAttrsToList (role: color: "${role}=${color}") (theme.roles or { }));
    } "bash ${./look/theme-bundle.sh}";

  # A kind is one picker: its bundles under their slugs, plus index.tsv, slug and display name in menu order.
  kinds = {
    theme = {
      entries = themes;
      bundle = themeBundle;
      default = cfg.theme;
    };
  };

  folder =
    kind:
    let
      inherit (kinds.${kind}) entries bundle;
      sorted = lib.sort (a: b: lib.toLower a.name < lib.toLower b.name) entries;
      slugs = map (entry: slug entry.name) entries;
    in
    assert lib.assertMsg (lib.allUnique slugs) "look: two ${kind} entries share a slug";
    pkgs.runCommand "look-${kind}s" { } ''
      mkdir $out
      ${lib.concatMapStrings (entry: "ln -s ${bundle entry} $out/${slug entry.name}\n") entries}
      printf '%s' ${
        lib.escapeShellArg (lib.concatMapStrings (entry: "${slug entry.name}\t${entry.name}\n") sorted)
      } >$out/index.tsv
    '';

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
        lib.escapeShellArg (toString (lib.mapAttrsToList (kind: k: "${kind}=${k.default}") kinds))
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
      type = lib.types.enum (map (theme: slug theme.name) themes);
      default = "gruvbox-dark";
      description = "The theme a fresh state starts from, and the one look-pick --reset goes back to. The pick itself lives in ~/.local/state/look, so no rebuild ever undoes it.";
    };
  };

  config = {
    home.packages = [
      picker
      gtkThemes
      icons
    ];

    xdg.dataFile = lib.mapAttrs' (
      kind: _: lib.nameValuePair "look/${kind}s" { source = folder kind; }
    ) kinds;

    xdg.configFile = {
      "gtk-4.0/gtk.css".source = state "theme/gtk4.css";
      "gtk-3.0/settings.ini".source = lib.mkForce (state "gtk3.ini");
      "gtk-4.0/settings.ini".source = lib.mkForce (state "gtk4.ini");
      "rofi/tasks.d/40-look.tsv".text = "> Change Theme\tlook-pick theme\n";
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

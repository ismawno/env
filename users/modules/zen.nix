# Zen's profiles: the shared user.js with host lines after it (Gecko takes a key's last user_pref, so a host override wins), and chrome/userChrome.css linked to mad.zen.userChrome.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mad.zen;
  shared = ../../dotfiles/shub/zen/user.js;
  userJs =
    if cfg.extraPrefs == "" then
      shared
    else
      pkgs.concatText "zen-user.js" [
        shared
        (pkgs.writeText "zen-user-host.js" "\n// Host-specific overrides.\n${cfg.extraPrefs}")
      ];
in
{
  options.mad.zen.extraPrefs = lib.mkOption {
    type = lib.types.lines;
    default = "";
    example = ''user_pref("media.av1.enabled", false);'';
    description = "Host-specific user_pref lines, appended after the shared set.";
  };

  options.mad.zen.userChrome = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/home/me/.local/state/look/theme/zen.css";
    description = "A path each profile's chrome/userChrome.css links to; Zen reads it at its start.";
  };

  # Zen announces DesktopEntry "zen" over MPRIS but ships zen-beta.desktop, so media widgets found no icon.
  config.xdg.dataFile."applications/zen.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Zen Browser
    Icon=zen-browser
    Exec=zen-beta %U
    NoDisplay=true
  '';

  # Zen names its profile directories at first launch, so match on the marker files; install -m, as cp keeps the store's 0444 and the next activation dies on it.
  config.home.activation.zenProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for root in "''${XDG_CONFIG_HOME:-$HOME/.config}"/zen "$HOME"/.zen; do
      for profile in "$root"/*/; do
        if [ -f "$profile/prefs.js" ] || [ -f "$profile/times.json" ]; then
          install -m 0644 "${userJs}" "$profile/user.js"
          ${lib.optionalString (cfg.userChrome != null) ''
            chrome=$profile/chrome/userChrome.css
            [ ! -e "$chrome" ] || [ -L "$chrome" ] || mv "$chrome" "$chrome.hm-bak"
            mkdir -p "$profile/chrome"
            ln -sfn ${lib.escapeShellArg cfg.userChrome} "$chrome"
          ''}
        fi
      done
    done
  '';
}

# Zen prefs: the shared user.js, plus optional host-specific lines appended after
# it. Gecko takes the last user_pref for a key, so a host override always wins.
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

  # Zen's profile directory name is generated at first launch, so match on the marker files.
  config.home.activation.zenUserJs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for root in "''${XDG_CONFIG_HOME:-$HOME/.config}"/zen "$HOME"/.zen; do
      for profile in "$root"/*/; do
        if [ -f "$profile/prefs.js" ] || [ -f "$profile/times.json" ]; then
          # install -m, not cp: cp preserves the store's 0444 and the next activation dies on it.
          install -m 0644 "${userJs}" "$profile/user.js"
        fi
      done
    done
  '';
}

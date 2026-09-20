{ ... }:

{
  imports = [ ../../users/modules/pkgs-unstable.nix ];

  # Pascal has no AV1 decoder, so off pushes YouTube to VP9, which it does decode.
  # Never share: smalltop's Iris Xe decodes AV1 in hardware and would regress.
  mad.zen.extraPrefs = ''
    user_pref("media.av1.enabled", false);
  '';
}

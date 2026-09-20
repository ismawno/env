{ ... }:

{
  imports = [ ../../users/modules/pkgs-unstable.nix ];

  # Pascal has no AV1 decoder, so off pushes YouTube to VP9, which it does decode.
  # Never share: smalltop's Iris Xe decodes AV1 in hardware and would regress.
  mad.zen.extraPrefs = ''
    user_pref("media.av1.enabled", false);
  '';

  # No eDP connector on this box, so smalltop's panel rule is left out.
  mad.hypr.monitors = [
    {
      output = "desc:AOC U27B3A ZXLQ8HA002427";
      mode = "3840x2160@60";
      position = "0x-1080";
      scale = 2;
    }
    {
      output = "";
      mode = "3840x2160@60";
      position = "auto";
      scale = 1;
    }
  ];
}

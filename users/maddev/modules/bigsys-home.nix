{ lib, pkgs, ... }:

{
  imports = [ ./hypr-desktop.nix ];

  # smicro-server-mobo-cant-sleep refuses suspend, so the power menu keeps Hibernate and drops Suspend.
  xdg.configFile."wlogout/layout".source = lib.mkForce (
    pkgs.runCommand "wlogout-layout" { } ''
      grep -v '"suspend"' ${../../../dotfiles/shub/wlogout/layout} > $out
    ''
  );

  # NVIDIA only: Pascal has no AV1 decoder (off pushes YouTube to VP9) and Gecko 153 blocklists VA-API on the proprietary driver.
  mad.zen.extraPrefs = ''
    user_pref("media.av1.enabled", false);
    user_pref("media.hardware-video-decoding.force-enabled", true);
  '';

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

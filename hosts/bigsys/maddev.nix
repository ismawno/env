{ ... }:

{
  imports = [ ../../users/modules/hypr-desktop.nix ];

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

  # Same folder IDs and ~ paths as the live config.xml, so nothing re-syncs; Atmosphere is the only peer.
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices.Atmosphere = {
        id = "LL7CJ3D-K2VWQWT-7XBOO6E-5ZCH3BP-PAMMOI2-TM3BX74-DSP4UX5-WAM6KQJ";
        addresses = [
          "tcp://100.123.34.78:22000"
          "dynamic"
        ];
      };
      folders = {
        "ObsidianVault" = {
          path = "~/Knowledge/ObsidianVault";
          devices = [ "Atmosphere" ];
        };
        "molten-river-knowledge" = {
          path = "~/Knowledge/molten-river-knowledge";
          devices = [ "Atmosphere" ];
        };
      };
      options = {
        globalAnnounceEnabled = true;
        localAnnounceEnabled = true;
        relaysEnabled = true;
        natEnabled = true;
        urAccepted = -1;
      };
    };
  };
}

{
  # Each host sets its own dataDir and folder paths; never copy configDir between hosts, the device ID is the identity.
  services.syncthing = {
    enable = true;
    user = "maddev";
    group = "users";
    configDir = "/home/maddev/.local/state/syncthing";
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
      # The names are the folder IDs (and default labels); they must match the peers' exactly or nothing pairs up.
      folders = {
        "ObsidianVault" = {
          type = "sendreceive";
          devices = [ "Atmosphere" ];
        };
        "molten-river-knowledge" = {
          type = "sendreceive";
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

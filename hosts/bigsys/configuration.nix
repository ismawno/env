# bigsys -- Xeon W-2155, GTX 1080; from nixos-generate-config, hand-maintained since.
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../users/maddev/modules/lan-discovery.nix
    ../../modules/ghostty-terminfo.nix
    ../../users/maddev/modules/bigsys-audio.nix
    ../../users/maddev/modules/fonts.nix
    ../../users/maddev/modules/maddev-base-system.nix
    ../../users/maddev/modules/login-keyring.nix
    ../../users/maddev/modules/syncthing-atmosphere.nix
    ../../users/maddev/modules/nvidia-gtx1080-legacy-580.nix
    ../../users/maddev/modules/fan-control.nix
    ../../users/maddev/modules/plymouth
    ../../users/maddev/modules/smicro-server-mobo-cant-sleep.nix
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-intel"
  ];

  boot.loader.grub.useOSProber = true;

  fileSystems."/" = {
    device = "/dev/mapper/luks-57ce758c-724d-46d8-a858-b645e4426b57";
    fsType = "ext4";
  };

  boot.initrd.luks.devices."luks-57ce758c-724d-46d8-a858-b645e4426b57".device =
    "/dev/disk/by-uuid/57ce758c-724d-46d8-a858-b645e4426b57";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/AF02-9640";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  networking.hostName = "bigsys";

  # Same folder paths as the live config.xml, so nothing re-syncs.
  services.syncthing = {
    dataDir = "/home/maddev/Knowledge";
    settings.folders = {
      "ObsidianVault".path = "/home/maddev/Knowledge/ObsidianVault";
      "molten-river-knowledge".path = "/home/maddev/Knowledge/molten-river-knowledge";
    };
  };

  # Allow unfree for Discord/Spotify
  nixpkgs.config.allowUnfree = lib.mkForce true;

  # schedutil, not performance (pins max clock) and not PPD (laptop-oriented).
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "schedutil";

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

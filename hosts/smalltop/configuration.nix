# smalltop -- Samsung Galaxy Book 3 Pro (NP960XFG-KC2IT, board P07RGU): i7-1360P, 16 GB, Iris Xe, CNVi wlo1 (no ethernet), ALC298, IPU6+ov02c10, TPM 2.0.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../users/maddev/modules/smalltop-disko.nix
    ../../users/maddev/modules/lan-discovery.nix
    ../../modules/ghostty-terminfo.nix
    ../../users/maddev/modules/smalltop-power-profiles.nix
    ../../users/maddev/modules/smalltop-battery.nix
    ../../users/maddev/modules/smalltop-audio.nix
    ../../users/maddev/modules/fonts.nix
    ../../users/maddev/modules/amoled-2k-215dpi-rendering.nix
    ../../users/maddev/modules/smalltop-hibernation-interlock.nix
    ../../users/maddev/modules/smalltop-rescue.nix
    ../../users/maddev/modules/intel-iris-xe-video.nix
    ../../users/maddev/modules/wifi-regdomain-es.nix
    ../../users/maddev/modules/smalltop-nomad-binds.nix
    ../../users/maddev/modules/hardware-poking-tools.nix
    ../../users/maddev/modules/maddev-base-system.nix
    ../../users/maddev/modules/login-keyring.nix
    ../../users/maddev/modules/plymouth
  ];

  mad.interlock.enable = true;

  networking.hostName = "smalltop";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # samsung_galaxybook needs >= 6.15; 26.05 removed _6_17/_6_19.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_18;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "vmd" # harmless if the BIOS is not in VMD/RST mode
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # GRUB core lives in ../../configuration.nix; the CachyOS entries in smalltop-hibernation-interlock.nix.
  boot.loader.efi.efiSysMountPoint = "/boot";

  # BOOT-CRITICAL: Samsung firmware discards EFI NVRAM, so boot lives on EFI/BOOT/BOOTX64.EFI.
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # boot.resumeDevice comes from smalltop-disko.nix; never point it at cachyos-swap (vault: Infra/MadTop, "MadTop hibernation").

  networking.useDHCP = lib.mkDefault true;

  # ov02c10 runs at 26 MHz, the in-tree driver demands 19.2; the out-of-tree route costs hibernation.
  hardware.ipu6.enable = false;

  services.hardware.bolt.enable = true; # Thunderbolt 4 / USB4

  # TPM exposed to userspace only: Secure Boot is off and no LUKS key is sealed to it.
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  services.fwupd.enable = true; # BIOS P07RGU.330.240529.ZQ; LVFS may have newer
  services.libinput.enable = true;

  # Never copy bigsys's syncthing state: the device ID is the identity.
  services.syncthing = {
    enable = true;
    user = "maddev";
    group = "users";
    dataDir = "/nomad/maddev/Knowledge";
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
          path = "/nomad/maddev/Knowledge/ObsidianVault";
          type = "sendreceive";
          devices = [ "Atmosphere" ];
        };
        "molten-river-knowledge" = {
          path = "/nomad/maddev/Knowledge/molten-river";
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

  users.users.maddev = {
    # Pinned: bind mounts do not translate ownership, so both distros must agree on the uid.
    uid = 1000;
    extraGroups = [
      "video"
      "input"
      "tss" # TPM2 access
    ];
  };
}

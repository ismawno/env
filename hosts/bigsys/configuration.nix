# bigsys -- Xeon W-2155, GTX 1080; from nixos-generate-config, hand-maintained since.
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
    ../modules/lan-discovery.nix
    ../modules/ghostty-terminfo.nix
    ./audio.nix
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
    "nct6775"
    "coretemp"
  ];

  programs.coolercontrol.enable = true;

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

  users.users.maddev = {
    isNormalUser = true;
    description = "maddev";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
  };

  # Allow unfree for Discord/Spotify
  nixpkgs.config.allowUnfree = lib.mkForce true;

  # schedutil, not performance (pins max clock) and not PPD (laptop-oriented).
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "schedutil";
  services.thermald.enable = true; # keeps the W-2155 at sustained turbo

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    # GTX 1080 (Pascal) was dropped by the 590+ drivers; 580 is its last supported branch.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
  };
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];
  hardware.graphics.enable = lib.mkForce true;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
    # The RDD file broker denies nvidia_drv_video.so /proc/version; Gecko 153 has no narrower pref.
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };

  services.tailscale.enable = true;

  boot.loader.grub2-theme.theme = lib.mkForce "whitesur";
  boot.plymouth.theme = lib.mkForce "pixels";
  boot.plymouth.themePackages = lib.mkForce [
    (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "pixels" ]; })
  ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

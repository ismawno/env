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
    ../../users/maddev/plymouth
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
    # GTX 1080 (Pascal) was dropped by the 590+ drivers; 580 is its last supported branch. Pascal has no GSP, so its firmware is dead weight.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    gsp.enable = false;
  };
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];
  # In the initrd, so Plymouth and the LUKS prompt get the GPU at native size; without it Plymouth waits 8 s, then takes simpledrm at 1024x768.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_drm"
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

  # xdg-open ran zen-beta in the foreground and blocked callers like `gh auth login`; the portal launches it detached.
  xdg.portal.xdgOpenUsePortal = true;

  boot.loader.grub2-theme.theme = lib.mkForce "whitesur";

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Home Manager runs standalone via home-rebuild.sh; the embedded copy re-applied a stale generation at every boot.
  home-manager.users = lib.mkForce { };
}

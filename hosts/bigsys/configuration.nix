# bigsys -- Xeon W-2155, GTX 1080 (Pascal, 580 is its last driver branch).
# Originally from nixos-generate-config; hand-maintained since.
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
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "nct6775"
    "coretemp"
  ];

  programs.coolercontrol.enable = true;

  boot.extraModulePackages = [ ];
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

  swapDevices = [ ];

  networking.hostName = "bigsys";

  users.users.maddev = {
    isNormalUser = true;
    description = "maddev";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };

  # Allow unfree for Discord/Spotify
  nixpkgs.config.allowUnfree = lib.mkForce true;

  # schedutil ramps 1.2 -> 4.5 GHz on demand and idles at the minimum. Not
  # "performance" (pins max clock) and not PPD (laptop-oriented).
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "schedutil";
  services.thermald.enable = true; # keeps the W-2155 at sustained turbo

  # Enable the NVIDIA driver
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    # GTX 1080 (Pascal) was dropped by the 590+ drivers; 580 is its last supported branch.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
  };
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];
  # GPU acceleration on wayland
  hardware.graphics.enable = lib.mkForce true;

  environment.sessionVariables = {
    # WLR_NO_HARDWARE_CURSORS = "1";

    # Direct Wayland to use NVIDIA
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";

    # nvidia_drv_video.so reads /proc/version at init and the RDD file broker denies
    # it, so decode drops to software. Gecko 153 has no narrower pref than this.
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };

  # NAS discovery, wifi powersave and LAN routing. Shared with smalltop.

  # TAILSCALE!!
  services.tailscale.enable = true;

  boot.loader.grub2-theme.theme = lib.mkForce "whitesur";
  boot.plymouth.theme = lib.mkForce "pixels";

  boot.plymouth.themePackages = lib.mkForce (
    with pkgs;
    [
      (adi1090x-plymouth-themes.override {
        selected_themes = [ "pixels" ];
      })
    ]
  );

  # DHCP on every interface; the recommended form for scripted networking.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp2s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp3s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

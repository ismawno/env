# smalltop -- Samsung Galaxy Book 3 Pro (NP960XFG-KC2IT, board P07RGU): i7-1360P, 16 GB, Iris Xe, CNVi wlo1 (no ethernet), ALC298, IPU6+ov02c10, TPM 2.0.
{
  config,
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}:

let
  # DATA-only dirs on @nomad, bind-mounted into $HOME (add a line + mv); never app STATE.
  nomadBinds = {
    "/home/maddev/Downloads" = "/nomad/maddev/Downloads";
    "/home/maddev/Documents" = "/nomad/maddev/Documents";
    "/home/maddev/Knowledge" = "/nomad/maddev/Knowledge";
    "/home/maddev/Pictures" = "/nomad/maddev/Pictures";
    "/home/maddev/Videos" = "/nomad/maddev/Videos";
    "/home/maddev/Music" = "/nomad/maddev/Music";
  };
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.disko.nixosModules.disko
    ./disko.nix
    ../modules/lan-discovery.nix
    ../modules/ghostty-terminfo.nix
    ./power-profiles.nix
    ./battery.nix
    ./audio.nix
    ./hibernation-interlock.nix
    ./rescue.nix
    ../../users/maddev/plymouth
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

  # GRUB core lives in ../../configuration.nix; the CachyOS entries in ./hibernation-interlock.nix.
  boot.loader.efi.efiSysMountPoint = "/boot";

  # BOOT-CRITICAL: Samsung firmware discards EFI NVRAM, so boot lives on EFI/BOOT/BOOTX64.EFI.
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # boot.resumeDevice comes from ./disko.nix; never point it at cachyos-swap (vault: Infra/MadTop, "MadTop hibernation").

  # i915 is what binds 8086:a7a0 on 6.18; xe is present but does not claim it.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # VA-API for Gen9+ (iHD)
      vpl-gpu-rt # oneVPL runtime, hardware encode
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # ~215 DPI: subpixel AA buys nothing and fringes at fractional scale.
  fonts = {
    fontconfig = {
      antialias = true;
      hinting = {
        enable = true;
        style = "slight"; # "full" would distort stems that are 3px wide here
      };
      subpixel = {
        rgba = "none";
        lcdfilter = "none"; # only meaningful with subpixel AA
      };
      useEmbeddedBitmaps = false; # low-DPI bitmaps are worse than the outline here
      defaultFonts = {
        monospace = [ "FiraCode Nerd Font Mono" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji # never the noto-fonts-emoji alias: it fails at build, not at eval
    ];
  };

  # Regdomain was observed as "00" (world), the most restrictive; user is in Spain.
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="ES"
  '';

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

  # ./disko.nix mounts @nomad root-owned; give maddev a place inside it.
  systemd.tmpfiles.rules = [
    "d /nomad 0755 root root -"
    "d /nomad/maddev 0700 maddev users -"
  ]
  ++ map (src: "d ${src} 0700 maddev users -") (lib.attrValues nomadBinds);

  # nofail: the sources do not exist on a fresh install and must not wedge boot.
  fileSystems = lib.mapAttrs (_target: src: {
    device = src;
    fsType = "none";
    depends = [ "/nomad" ]; # make the generated mount unit require /nomad
    options = [
      "bind"
      "nofail"
      "x-gvfs-hide"
    ];
  }) nomadBinds;

  # xdg-open ran the browser in the foreground and blocked callers like `gh auth login`; the portal launches it detached.
  xdg.portal.xdgOpenUsePortal = true;

  # App tokens (gh) are kept encrypted with the login password, which ly hands to the keyring at sign-in; mad.hypr.keyring finishes that startup in the session.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.ly.enableGnomeKeyring = true;

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

  # maddev prefers whitesur over the shared tela.
  boot.loader.grub2-theme.theme = lib.mkForce "whitesur";

  users.users.maddev = {
    isNormalUser = true;
    # Pinned: bind mounts do not translate ownership, so both distros must agree on the uid.
    uid = 1000;
    description = "maddev";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "tss" # TPM2 access
    ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    # Hardware poking, all read-only by default.
    pciutils
    usbutils
    nvme-cli
    btrfs-progs
    cryptsetup
    lvm2
    alsa-utils # aplay -l, amixer, speaker-test
    v4l-utils # v4l2-ctl --list-devices
    iw # iw reg get, to confirm the ES regdomain took
    powertop
    tpm2-tools
  ];

  # Home Manager runs standalone via home-rebuild.sh; the embedded copy re-applied a stale generation at every boot.
  home-manager.users = lib.mkForce { };
}

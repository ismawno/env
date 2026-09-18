# smalltop -- Samsung Galaxy Book 3 Pro (NP960XFG-KC2IT, board P07RGU). i7-1360P,
# 16 GB, Iris Xe, CNVi wlo1 (no ethernet), ALC298 audio, IPU6+ov02c10, TPM 2.0.
{
  config,
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}:

let
  # DATA-only dirs on @nomad, bind-mounted into $HOME below (add a line + `mv`).
  # App STATE (zen profile, Steam, ~/Development) stays per-distro -- never add it.
  nomadBinds = {
    "/home/maddev/Downloads" = "/nomad/maddev/Downloads";
    "/home/maddev/Documents" = "/nomad/maddev/Documents";
    "/home/maddev/Knowledge" = "/nomad/maddev/Knowledge";
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
    ./audio.nix
    ./hibernation-interlock.nix
    ./rescue.nix
  ];

  mad.interlock.enable = true;

  networking.hostName = "smalltop";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # mkForce over the shared 6_12 pin: samsung_galaxybook needs >= 6.15 (kbd
  # backlight, platform profile, charge limit). nixpkgs 26.05 removed _6_17/_6_19.
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

  # BOOT-CRITICAL, DO NOT REVERT: Samsung firmware discards EFI NVRAM entries, so
  # boot lives on EFI/BOOT/BOOTX64.EFI. Reverting bricks the NEXT rebuild, not this one.
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # boot.resumeDevice comes from ./disko.nix; redeclaring it here conflicts. Never
  # point it at cachyos-swap -- see the CachyOS note in Knowledge/Infra/MadTop.

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

  # ~215 DPI panel. rgba = "none" is deliberate: fractional scale resamples buffers
  # into colour fringes and subpixel AA buys nothing here. Revisit only at integer scale.
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
      # NOT `noto-fonts-emoji`: it is an alias that throws only when forced, so it
      # passes `nix flake check --no-build` and fails at build time.
      noto-fonts-color-emoji
    ];
  };

  # Regdomain was observed as "00" (world), the most restrictive; user is in Spain.
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="ES"
  '';

  networking.useDHCP = lib.mkDefault true;

  # Audio lives in ./audio.nix (imported above).

  # Off deliberately: ov02c10 runs at 26 MHz, the in-tree driver demands 19.2 and
  # will not probe. The out-of-tree route freezes on s2idle >=6.16 -- costs hibernation.
  hardware.ipu6 = {
    enable = false;
    platform = "ipu6ep";
  };

  services.hardware.bolt.enable = true; # Thunderbolt 4 / USB4

  # TPM exposed to userspace only: Secure Boot is off and no LUKS key is sealed to it.
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # Power profiles live in ./power-profiles.nix (imported above);
  # samsung_galaxybook exposes the ACPI platform_profile that PPD drives.
  services.fwupd.enable = true; # BIOS P07RGU.330.240529.ZQ; LVFS may have newer
  services.libinput.enable = true;

  # samsung_galaxybook also gives kbd_backlight, charge_control_end_threshold and
  # /sys/firmware/acpi/platform_profile -- no module params or acpi_osi needed.

  # ./disko.nix mounts @nomad at /nomad root-owned; give maddev a place inside it.
  # ("nomad" is the shared data subvolume, unrelated to hosts/nomad/ in this flake.)
  systemd.tmpfiles.rules = [
    "d /nomad 0755 root root -"
    "d /nomad/maddev 0700 maddev users -"
  ]
  ++ map (src: "d ${src} 0700 maddev users -") (lib.attrValues nomadBinds);

  # Bind the shared dirs into $HOME so apps see their usual paths. `nofail` is
  # deliberate: the sources do not exist on a fresh install and must not wedge boot.
  fileSystems = lib.mapAttrs (_target: src: {
    device = src;
    fsType = "none";
    depends = [ "/nomad" ]; # make the generated mount unit require /nomad
    options = [
      "bind"
      "nofail"
    ];
  }) nomadBinds;

  # bigsys is logged out, so there is no state to migrate -- just `tailscale up`.
  services.tailscale.enable = true;

  # Never copy bigsys's syncthing state: the device ID is the identity and two
  # machines answering to one will fight. override* = false keeps web-UI additions.
  services.syncthing = {
    enable = true;
    user = "maddev";
    group = "users";
    dataDir = "/nomad/maddev/Knowledge";
    configDir = "/home/maddev/.local/state/syncthing";
    overrideDevices = false;
    overrideFolders = false;
    settings = {
      devices = {
        # Public device IDs. These are public keys, not secrets.
        Atmosphere.id = "LL7CJ3D-K2VWQWT-7XBOO6E-5ZCH3BP-PAMMOI2-TM3BX74-DSP4UX5-WAM6KQJ";
        WorkPC.id = "MUXVN5R-FEXPENP-4XNQPG7-XHCQEUH-E6MYV74-LQFFMMZ-ED3IBRT-RJALVQC";
        FairCaly.id = "M555SO5-7CSX6PN-GHNILWD-7Q7MW4R-DRJUIB4-WYOOMUH-NRIYBZK-PMYRIA5";
        bigsys.id = "NLGFRBA-4I2FD36-BF57YFJ-VUPZOKS-2TJHSUC-N7Z37J4-AQ73CRV-UMZ7FA6";
        blanket.id = "OFVY5ZC-EEZD2RI-NV3YFUD-I64ALWY-FY6FYUK-W62IINS-YWAOZW2-4SL6GQE";
        androidmoto.id = "W2DN3FF-YRPMIEO-XV2HOYB-ZQSCP3T-EJH3OIC-Y7WDC3N-EJSBFST-4FUL3AQ";
        madsystem-skandal.id = "ZTX4L66-KQSPHNX-J2OVFZT-3BFEDHL-E47MEM6-N4XGPAJ-MYLMKTC-CFFONQC";
        FP5.id = "4MQOIMD-JX4EUOA-ZF7ONSM-ZKBBDHX-PAT37XD-EBQEQFC-4Y2DCIU-PFZK3QG";
      };
      folders = {
        # Folder IDs must match the peers' exactly or nothing pairs up.
        "ObsidianVault" = {
          id = "ObsidianVault";
          label = "ObsidianVault";
          path = "/nomad/maddev/Knowledge/ObsidianVault";
          type = "sendreceive";
          devices = [
            "Atmosphere"
            "WorkPC"
            "FairCaly"
            "bigsys"
            "blanket"
            "androidmoto"
            "madsystem-skandal"
            "FP5"
          ];
        };
        "molten-river-knowledge" = {
          id = "molten-river-knowledge";
          path = "/nomad/maddev/Knowledge/molten-river/knowledge-backups";
          type = "sendreceive";
          devices = [
            "Atmosphere"
            "bigsys"
          ];
        };
      };
    };
  };

  # maddev prefers whitesur/pixels over the shared tela/colorful_loop.
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

  users.users.maddev = {
    isNormalUser = true;
    # Pinned: bind mounts do not translate ownership, so NixOS and CachyOS must
    # agree on maddev's uid or shared files on @nomad show up owned by a stranger.
    uid = 1000;
    description = "maddev";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "tss" # TPM2 access
    ];
    packages = with pkgs; [ ];
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
}

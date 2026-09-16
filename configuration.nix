{ config, pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.warn-dirty = false;

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = true;

      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
      };

      grub2-theme = {
        enable = true;
        theme = "tela";
        footer = true;
      };

    };

    consoleLogLevel = 3;
    initrd.systemd.enable = true;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];

    plymouth = {
      enable = true;
      theme = "colorful_loop";
      themePackages = with pkgs; [
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "colorful_loop" ];
        })
      ];
    };
    kernelPackages = pkgs.linuxPackages_6_12;
  };

  networking.networkmanager.enable = true;
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "65536";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "65536";
    }
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
      };
    };
  };

  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_ES.UTF-8";
    LC_IDENTIFICATION = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_NAME = "es_ES.UTF-8";
    LC_NUMERIC = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_TELEPHONE = "es_ES.UTF-8";
    LC_TIME = "es_ES.UTF-8";
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.fira-code
      noto-fonts
      noto-fonts-color-emoji
    ];

    # Without defaultFonts, "monospace" resolved to DejaVu Sans Mono on bigsys and
    # Nerd Font icons rendered as tofu. Use noto-fonts-color-emoji, never the alias.
    fontconfig = {
      defaultFonts = {
        monospace = [ "FiraCode Nerd Font Mono" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
      # Subpixel (rgba) is deliberately NOT set here: it is only safe at integer
      # compositor scale and harmful on non-RGB-stripe panels. Set it per-host.
      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
      };
      useEmbeddedBitmaps = false;
    };
  };

  environment.systemPackages = with pkgs; [ home-manager ];
  programs.zsh.enable = true;
  programs.git.enable = true;
  programs.hyprland.enable = true;
  programs.nano.enable = false;
  programs.command-not-found.enable = false;

  # Audio lives in modules/audio.nix, imported per host via hosts/<name>/audio.nix.
  services.xserver.enable = false;
  services.displayManager.ly.enable = true;
  services.openssh.enable = true;

  # Release whose stateful-data defaults this system was built against.
  # Leave at the first install's version; read the docs before ever changing it.
  system.stateVersion = "25.05";

}

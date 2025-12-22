{ config, pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.warn-dirty = false;

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
      theme = "abstract_ring_alt";
      themePackages = with pkgs; [
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "abstract_ring_alt" ];
        })
      ];
    };
    kernelPackages = pkgs.linuxPackages_6_12;
  };

  networking.networkmanager.enable = true;

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
    packages = with pkgs; [ nerd-fonts.fira-code ];
  };

  nixpkgs.config.allowUnfree = false;

  environment.systemPackages = with pkgs; [ home-manager ];
  programs.zsh.enable = true;
  programs.git.enable = true;
  programs.hyprland.enable = true;
  programs.nano.enable = false;
  programs.command-not-found.enable = false;

  services.pulseaudio.enable = false;
  services.xserver.enable = false;
  services.displayManager.ly.enable = true;
  services.openssh.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}

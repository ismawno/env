# Every theme look-pick offers: a Ghostty theme of the same name plus a GTK 3 and GTK 4 theme of that palette, which the bundle build checks.
{ lib, pkgs }:

let
  gtk = package: name: { inherit package name; };
  builtin = name: {
    package = null;
    inherit name;
  };
  catppuccin = pkgs.magnetic-catppuccin-gtk;
  fox =
    tweak:
    gtk (
      pkgs.nightfox-gtk-theme.override {
        colorVariants = [ "dark" ];
        tweakVariants = [ tweak ];
      }
    );
  tokyonight =
    tweak:
    gtk (
      pkgs.tokyonight-gtk-theme.override {
        colorVariants = [ "dark" ];
        tweakVariants = [ tweak ];
      }
    );
  everforestLightMedium = pkgs.everforest-gtk-theme.overrideAttrs (old: {
    installPhase =
      lib.replaceStrings [ "--theme all" ] [ "--theme default --color light --tweaks medium" ]
        old.installPhase;
  });
in
[
  {
    name = "Adwaita";
    gtk = builtin "Adwaita";
  }
  {
    name = "Adwaita Dark";
    gtk = builtin "Adwaita-dark";
  }
  {
    name = "Breeze";
    gtk = gtk pkgs.kdePackages.breeze-gtk "Breeze-Dark";
  }
  {
    name = "Carbonfox";
    gtk = fox "carbonfox" "Nightfox-Dark-Carbonfox";
  }
  {
    name = "Catppuccin Frappe";
    gtk = gtk (catppuccin.override { tweaks = [ "frappe" ]; }) "Catppuccin-GTK-Dark-Frappe";
  }
  {
    name = "Catppuccin Latte";
    gtk = gtk (catppuccin.override { shade = "light"; }) "Catppuccin-GTK-Light";
  }
  {
    name = "Catppuccin Macchiato";
    gtk = gtk (catppuccin.override { tweaks = [ "macchiato" ]; }) "Catppuccin-GTK-Dark-Macchiato";
  }
  {
    name = "Catppuccin Mocha";
    gtk = gtk catppuccin "Catppuccin-GTK-Dark";
  }
  {
    name = "Dayfox";
    gtk = gtk pkgs.nightfox-gtk-theme "Nightfox-Light";
  }
  {
    name = "Dracula";
    gtk = gtk pkgs.dracula-theme "Dracula";
  }
  {
    name = "Duskfox";
    gtk = fox "duskfox" "Nightfox-Dark-Duskfox";
  }
  {
    name = "Everforest Dark Hard";
    gtk = gtk pkgs.everforest-gtk-theme "Everforest-Dark";
  }
  {
    name = "Everforest Light Med";
    gtk = gtk everforestLightMedium "Everforest-Light-Medium";
  }
  # The default, pinned to the exact shades waybar, swaync, qt6ct and Hyprland had before look-pick.
  {
    name = "Gruvbox Dark";
    gtk = gtk (pkgs.gruvbox-gtk-theme.override {
      colorVariants = [ "dark" ];
      tweakVariants = [ "medium" ];
    }) "Gruvbox-Dark-Medium";
    roles = {
      button = "#32302f";
      bg1 = "#3c3836";
      midlight = "#45403d";
      bg2 = "#504945";
      light = "#5a524c";
      bg_dark = "#1d2021";
      fg2 = "#d5c4a1";
      dim = "#7c6f64";
      subtle = "#a89984";
      inactive = "#a4997f";
      on_crit = "#fbf1c7";
      blue_dark = "#076678";
      week = "#99ffdd";
      today = "#ff6699";
    };
  }
  {
    name = "Gruvbox Dark Hard";
    gtk = gtk pkgs.gruvbox-gtk-theme "Gruvbox-Dark";
  }
  {
    name = "Gruvbox Light";
    gtk = gtk pkgs.gruvbox-gtk-theme "Gruvbox-Light";
  }
  {
    name = "Gruvbox Material Dark";
    gtk = gtk pkgs.gruvbox-material-gtk-theme "Gruvbox-Material-Dark";
  }
  {
    name = "Kanagawa Wave";
    gtk = gtk pkgs.kanagawa-gtk-theme "Kanagawa-B";
  }
  {
    name = "Nightfox";
    gtk = gtk pkgs.nightfox-gtk-theme "Nightfox-Dark";
  }
  {
    name = "Nord";
    gtk = gtk pkgs.nordic "Nordic";
  }
  {
    name = "Nord Light";
    gtk = gtk pkgs.nordic "Nordic-Polar";
  }
  {
    name = "Nordfox";
    gtk = fox "nordfox" "Nightfox-Dark-Nordfox";
  }
  {
    name = "Rose Pine";
    gtk = gtk pkgs.rose-pine-gtk-theme "rose-pine";
  }
  {
    name = "Rose Pine Dawn";
    gtk = gtk pkgs.rose-pine-gtk-theme "rose-pine-dawn";
  }
  {
    name = "Rose Pine Moon";
    gtk = gtk pkgs.rose-pine-gtk-theme "rose-pine-moon";
  }
  {
    name = "Terafox";
    gtk = fox "terafox" "Nightfox-Dark-Terafox";
  }
  {
    name = "TokyoNight Day";
    gtk = gtk pkgs.tokyonight-gtk-theme "Tokyonight-Light";
  }
  {
    name = "TokyoNight Moon";
    gtk = tokyonight "moon" "Tokyonight-Dark-Moon";
  }
  {
    name = "TokyoNight Night";
    gtk = gtk pkgs.tokyonight-gtk-theme "Tokyonight-Dark";
  }
  {
    name = "TokyoNight Storm";
    gtk = tokyonight "storm" "Tokyonight-Dark-Storm";
  }
]

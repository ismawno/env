{ pkgs, ... }:

{
  # Without defaultFonts, monospace resolved to DejaVu Sans Mono and Nerd Font icons rendered as tofu.
  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji # never the noto-fonts-emoji alias: it fails at build, not at eval
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "FiraCode Nerd Font Mono" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
      useEmbeddedBitmaps = false;
    };
  };
}

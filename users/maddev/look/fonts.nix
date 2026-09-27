# Every mono font look-pick offers: family is the one Ghostty asks for, mono the strictly monospaced one behind the desktop's "monospace".
{ lib, pkgs }:

let
  # Iosevka and Monaspace ship dozens of styles each, 1 GiB and 477 MiB; four styles are all a terminal and the alias ever ask for.
  styles =
    package: prefixes:
    pkgs.runCommand "${package.pname}-four-styles" { } ''
      mkdir -p $out/share/fonts
      ${lib.concatMapStrings (prefix: ''
        for style in Regular Bold Italic BoldItalic; do
          found=$(find ${package}/share/fonts -name "${prefix}-$style.*")
          [ -n "$found" ] || { echo "${package.name} has no ${prefix}-$style" >&2; exit 1; }
          cp $found $out/share/fonts/
        done
      '') prefixes}
    '';
in
[
  {
    name = "Cascadia Code";
    package = pkgs.nerd-fonts.caskaydia-cove;
    family = "CaskaydiaCove Nerd Font";
    mono = "CaskaydiaCove Nerd Font Mono";
  }
  {
    name = "Cousine";
    package = pkgs.nerd-fonts.cousine;
    family = "Cousine Nerd Font";
    mono = "Cousine Nerd Font Mono";
  }
  {
    name = "Fira Code";
    package = pkgs.nerd-fonts.fira-code;
    family = "FiraCode Nerd Font";
    mono = "FiraCode Nerd Font Mono";
  }
  {
    name = "Iosevka";
    package = styles pkgs.nerd-fonts.iosevka [
      "IosevkaNerdFont"
      "IosevkaNerdFontMono"
    ];
    family = "Iosevka Nerd Font";
    mono = "Iosevka Nerd Font Mono";
  }
  {
    name = "JetBrains Mono";
    package = pkgs.nerd-fonts.jetbrains-mono;
    family = "JetBrainsMono Nerd Font";
    mono = "JetBrainsMono Nerd Font Mono";
  }
  # Upstream's own Nerd Font build of 1.400; nerd-fonts.monaspace patches the older 1.200.
  {
    name = "Monaspace Neon";
    package = styles pkgs.monaspace.nerdfonts [ "MonaspaceNeonNF" ];
    family = "Monaspace Neon NF";
    mono = "Monaspace Neon NF";
  }
  {
    name = "Source Code Pro";
    package = pkgs.nerd-fonts.sauce-code-pro;
    family = "SauceCodePro Nerd Font";
    mono = "SauceCodePro Nerd Font Mono";
  }
]

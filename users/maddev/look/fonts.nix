# Every mono font look-pick offers, fetched from its free upstream at a pinned version: family is the one Ghostty and the GTK and Qt UI ask for, mono the one behind "monospace", the bars, the menus and the lock screen.
{ lib, pkgs }:

let
  # google/fonts at one commit, so every file keeps its hash.
  google =
    name: files:
    pkgs.linkFarm "${name}-font" (
      lib.mapAttrsToList (file: hash: {
        name = "share/fonts/${file}";
        path = pkgs.fetchurl {
          name = lib.strings.sanitizeDerivationName file;
          url = "https://raw.githubusercontent.com/google/fonts/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl/${name}/${lib.escapeURL file}";
          inherit hash;
        };
      }) files
    );

  # A release archive trimmed inside its fixed-output fetch, so the whole archive never reaches the store.
  release =
    name: url: hash: path:
    pkgs.fetchzip {
      inherit url hash;
      name = "${name}-font";
      stripRoot = false;
      postFetch = ''
        mkdir "$TMPDIR/fonts"
        ${lib.concatMapStrings
          (style: "mv \"$out\"/${lib.escapeShellArg (path style)} \"$TMPDIR/fonts/\"\n")
          [
            "Regular"
            "Bold"
            "Italic"
            "BoldItalic"
          ]
        }
        rm -r "$out"
        mkdir -p "$out/share"
        mv "$TMPDIR/fonts" "$out/share/fonts"
      '';
    };
in
[
  {
    name = "Cascadia Code";
    package =
      release "cascadia-code"
        "https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip"
        "sha256-OMr5N/KDOqXhhsDmdrZKZiEmKaEPQ/CvLT+3FJP0xaU="
        (style: "ttf/static/CascadiaCode-${style}.ttf");
    family = "Cascadia Code";
    mono = "Cascadia Code";
  }
  {
    name = "Cousine";
    package = google "cousine" {
      "Cousine-Regular.ttf" = "sha256-HaIiUGdfxMQvzzqXNsRLwFcFFhBTMUQ7Zj/Vz70UEv4=";
      "Cousine-Bold.ttf" = "sha256-F8inJFFW0iU1McnlKUdJN7Cdn2QcWudpXF4z8igi7vQ=";
      "Cousine-Italic.ttf" = "sha256-6ip2rj0OzpzVnw0w/cCN1w6PX0V77uWwhSp7UMIobHw=";
      "Cousine-BoldItalic.ttf" = "sha256-hI6Fhyb+4K4nt1TkzWonVSCb8UKKjJH3R2ltWMM5BsM=";
    };
    family = "Cousine";
    mono = "Cousine";
  }
  {
    name = "Fira Code";
    package = google "firacode" {
      "FiraCode[wght].ttf" = "sha256-kzWwgrPHhQ2YpktYTzQX9lNV80cSeLte64xsDoZXrus=";
    };
    family = "Fira Code";
    mono = "Fira Code";
  }
  # Unhinted: under his hintslight and Ghostty's light hinting FreeType auto-hints anyway, and the hinted set is 13 MB more.
  {
    name = "Iosevka";
    package =
      release "iosevka"
        "https://github.com/be5invis/Iosevka/releases/download/v34.9.0/PkgTTF-Unhinted-Iosevka-34.9.0.zip"
        "sha256-anX5Ivmz9iFgIMaSzezoDgYrltA/sbtRjHSJGwCJpRs="
        (style: "Iosevka-${style}.ttf");
    family = "Iosevka";
    mono = "Iosevka";
  }
  # The Nerd build home.nix installs, so this pick keeps the bar, the panels and GTK as they were before look-pick, the bar's own character variants included.
  {
    name = "JetBrains Mono";
    package = pkgs.nerd-fonts.jetbrains-mono;
    family = "JetBrainsMono Nerd Font";
    mono = "JetBrainsMono Nerd Font Mono";
    features = ''"zero", "ss01", "ss02", "ss03", "ss04", "ss05", "cv31"'';
  }
  {
    name = "Monaspace Neon";
    package =
      release "monaspace-neon"
        "https://github.com/githubnext/monaspace/releases/download/v1.400/monaspace-static-v1.400.zip"
        "sha256-okzYBugZjTSb9iFcHeQtp7AfhYWznUFv36dPvidgqsg="
        (style: "Static Fonts/Monaspace Neon/MonaspaceNeon-${style}.otf");
    family = "Monaspace Neon";
    mono = "Monaspace Neon";
  }
  {
    name = "Source Code Pro";
    package = google "sourcecodepro" {
      "SourceCodePro[wght].ttf" = "sha256-tAD8WE4Qr/JdDndc4YG0/BxeobXcN7ga6yCEN1uUV5A=";
      "SourceCodePro-Italic[wght].ttf" = "sha256-bbd9Jap7MO/0STBbXJmOR1aUx005hCESfqWmD1NkE80=";
    };
    family = "Source Code Pro";
    mono = "Source Code Pro";
  }
]

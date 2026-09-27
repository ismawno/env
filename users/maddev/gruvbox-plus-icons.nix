{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gruvbox-plus-icon-pack";
  version = "6.6.0";

  src = fetchFromGitHub {
    owner = "SylEleuth";
    repo = "gruvbox-plus-icon-pack";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Xv/9HUdTloQNuUcgTeprcomZFzZEoYaWt9DdYNg++LI=";
  };

  # The dark set for dark themes and the light one for light themes; the spare folder colours stay out, nothing reads them.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    cp -r Gruvbox-Plus-Dark Gruvbox-Plus-Light $out/share/icons/
    runHook postInstall
  '';

  meta = {
    description = "Gruvbox-coloured icon pack for dark and light themes";
    homepage = "https://github.com/SylEleuth/gruvbox-plus-icon-pack";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
})

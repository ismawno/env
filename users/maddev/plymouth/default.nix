{ lib, pkgs, ... }:

let
  # "Forested hills in Lysekil in fog" by W.carter, CC BY-SA 4.0; pinned like ../wallpaper.nix, never in git.
  photo = pkgs.fetchurl {
    name = "lysekil-fog.png";
    url = "https://media.githubusercontent.com/media/Mars-Wave/caelestia-wallpapers-AMOLED/bcd763a1a34780a546aed4557586bbb198220d54/wallpapers/nature-foggy-forest/Forested%20hills%20in%20Lysekil%20in%20fog%20-%20B%26W.png";
    hash = "sha256-kqauakv66CVx+ePf49ir8T+giubxmADxWQnqH8RYcro=";
  };

  # Field and dot drawn at their final size per common screen height; the script scales the 2160 pair for any other.
  theme = pkgs.runCommand "plymouth-theme-forest" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    dir=$out/share/plymouth/themes/forest
    mkdir -p $dir
    substitute ${./forest.plymouth} $dir/forest.plymouth --replace-fail @dir@ $dir
    cp ${./forest.script} $dir/forest.script
    magick ${photo} -colorspace Gray -strip $dir/background.png
    for h in 720 768 800 900 1024 1050 1080 1200 1440 1600 1800 2160; do
      bh=$((h * 52 / 1000))
      ds=$((bh * 26 / 100))
      c=$(((ds - 1) / 2)).$(((ds - 1) % 2 * 5))
      magick -size $((bh * 8))x$bh xc:none -fill "rgba(12,12,12,0.59)" -stroke "rgba(240,240,240,0.43)" \
        -strokewidth $((h >= 1350 ? 2 : 1)) -draw "roundrectangle 1,1 $((bh * 8 - 2)),$((bh - 2)) $(((bh - 1) / 2)),$(((bh - 1) / 2))" $dir/entry-$h.png
      magick -size ''${ds}x$ds xc:none -fill "rgb(240,240,240)" -draw "circle $c,$c $c,0.5" $dir/dot-$h.png
    done
  '';
in
{
  boot.plymouth = {
    theme = lib.mkForce "forest";
    themePackages = lib.mkForce [ theme ];
    # Real pixels: at Plymouth's automatic 2x the photo is drawn at half resolution, then upscaled.
    extraConfig = "DeviceScale=1";
  };

  systemd.services.plymouth-poweroff.enable = false;
  systemd.services.plymouth-reboot.enable = false;
  systemd.services.plymouth-halt.enable = false;
  systemd.services.plymouth-kexec.enable = false;
}

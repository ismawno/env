{ lib, ... }:

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
  # smalltop-disko.nix mounts @nomad root-owned; give maddev a place inside it.
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
}

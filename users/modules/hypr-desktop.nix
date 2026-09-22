# Desktop profile for the shared Hyprland Lua tree: shub/desktop.lua needs no facts of its own.
{ lib, pkgs, ... }:

let
  wlogout = "${../../dotfiles/shub}/wlogout";
in
{
  imports = [ ./hypr-host.nix ];

  mad.hypr.facts.kind = "desktop";

  # A desktop has no swap to hibernate into, so its power menu goes without Hibernate.
  xdg.configFile.wlogout.source = lib.mkForce (
    pkgs.runCommand "wlogout" { } ''
      mkdir $out
      ln -s ${wlogout}/style.css ${wlogout}/icons $out/
      grep -v '"hibernate"' ${wlogout}/layout > $out/layout
    ''
  );
}

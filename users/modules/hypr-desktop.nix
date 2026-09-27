# Desktop profile for the shared Hyprland Lua tree: shub/desktop.lua needs no facts of its own.
{ lib, pkgs, ... }:

{
  imports = [ ./hypr-host.nix ];

  mad.hypr.facts.kind = "desktop";

  # A desktop has no swap to hibernate into, so its power menu goes without Hibernate.
  xdg.configFile."wlogout/layout".source = lib.mkForce (
    pkgs.runCommand "wlogout-layout" { } ''
      grep -v '"hibernate"' ${../../dotfiles/shub/wlogout/layout} > $out
    ''
  );
}

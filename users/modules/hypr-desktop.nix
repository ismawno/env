# Desktop profile for the shared Hyprland Lua tree: shub/desktop.lua needs no facts of its own.
{ ... }:

{
  imports = [ ./hypr-host.nix ];

  mad.hypr.facts.kind = "desktop";
}

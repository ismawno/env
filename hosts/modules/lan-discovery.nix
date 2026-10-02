# Network setup shared by maddev's two machines only: smalltop and bigsys.
# Imported from those two host files, so nothing else on the flake is affected.
{ pkgs, ... }:

{
  # File managers only see NAS boxes that announce themselves on the network.
  # Nothing here names a server, so a new NAS shows up on its own.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Gives Thunar its "Browse Network" entry and the ability to open shares.
  services.gvfs = {
    enable = true;
    package = pkgs.gvfs; # the 'light' build has no SMB support
  };

  # smbclient/nmblookup, for checking shares outside of Thunar.
  environment.systemPackages = with pkgs; [ samba ];

  # allumeur's 192.168.1.0/24 wins over any local 192.168.1.x network, as on the phone; `tailscale down` reaches the local one.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    extraSetFlags = [ "--accept-routes" ];
  };
}

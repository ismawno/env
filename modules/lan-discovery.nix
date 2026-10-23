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

  # Tailscale was sending all home-network traffic through allumeur. That made
  # the kernel discard the NAS's announcements and slowed every local transfer.
  #
  # This talks straight to anything on the same network as us, and still falls
  # back to Tailscale when we are away, so the homelab stays reachable.
  #
  # To undo it while running: sudo ip rule del pref 5205
  systemd.services.prefer-direct-lan-routes = {
    description = "Prefer directly-connected routes over Tailscale subnet routes";
    after = [
      "network.target"
      "tailscaled.service"
    ];
    wants = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # 5205 sits just below Tailscale's own rules, so it is never overwritten.
      ExecStart = pkgs.writeShellScript "prefer-direct-lan-up" ''
        ${pkgs.iproute2}/bin/ip rule del pref 5205 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip rule add pref 5205 lookup main suppress_prefixlength 0
      '';
      ExecStop = pkgs.writeShellScript "prefer-direct-lan-down" ''
        ${pkgs.iproute2}/bin/ip rule del pref 5205 2>/dev/null || true
      '';
    };
  };
}

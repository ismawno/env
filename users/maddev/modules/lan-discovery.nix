# Network setup for maddev's two machines, smalltop and bigsys.
{ lib, pkgs, ... }:

let
  homeRouterMac = "80:69:1a:1f:1d:8a";
  homeSubnet = "192.168.1.0/24";
  # Just ahead of Tailscale's 5210-5270, so main beats table 52 for the home subnet.
  directLanPref = "5205";
in
{
  # File managers only see NAS boxes that announce themselves; nothing here names a server.
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

  # allumeur's 192.168.1.0/24 wins over any foreign 192.168.1.x network, as on the phone; behind the home router the dispatcher below goes direct.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    extraSetFlags = [ "--accept-routes" ];
  };

  # Decides from the current default route, not from whichever interface fired the event.
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "home-lan-direct" ''
        export PATH=${
          lib.makeBinPath [
            pkgs.iproute2
            pkgs.iputils
            pkgs.gawk
          ]
        }

        case "$2" in
          up | down | dhcp4-change | connectivity-change | reapply | vpn-up | vpn-down) ;;
          *) exit 0 ;;
        esac

        rule=(to ${homeSubnet} lookup main pref ${directLanPref})

        read -r gw dev < <(ip -4 route show table main default | awk '
          {
            gw = ""; dev = ""; metric = 0
            for (i = 1; i < NF; i++) {
              if ($i == "via") gw = $(i + 1)
              else if ($i == "dev") dev = $(i + 1)
              else if ($i == "metric") metric = $(i + 1) + 0
            }
            if (gw != "" && dev != "tailscale0" && dev != "lo" && (!found || metric < best)) {
              found = 1; best = metric; out = gw " " dev
            }
          }
          END { if (found) print out }')

        gateway_mac() {
          ip -4 neigh show to "$gw" dev "$dev" | awk '{ for (i = 1; i < NF; i++) if ($i == "lladdr") print tolower($(i + 1)) }'
        }

        at_home=0
        if [ -n "$gw" ] && [ -n "$dev" ]; then
          mac=$(gateway_mac)
          # Right after link-up the gateway may not be in the ARP table yet.
          if [ -z "$mac" ]; then
            ping -c1 -W1 -I "$dev" "$gw" >/dev/null 2>&1
            mac=$(gateway_mac)
          fi
          [ "$mac" = "${lib.toLower homeRouterMac}" ] && at_home=1
        fi

        if [ "$at_home" = 1 ]; then
          [ -n "$(ip -4 rule show "''${rule[@]}")" ] || ip -4 rule add "''${rule[@]}"
        else
          while ip -4 rule del "''${rule[@]}" 2>/dev/null; do :; done
        fi
      '';
    }
  ];
}

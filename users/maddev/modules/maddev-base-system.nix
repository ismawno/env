{ lib, pkgs, ... }:

{
  users.users.maddev = {
    isNormalUser = true;
    description = "maddev";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
  };

  # xdg-open ran the browser in the foreground and blocked callers like `gh auth login`; the portal launches it detached.
  xdg.portal.xdgOpenUsePortal = true;

  # maddev prefers whitesur over the shared tela.
  boot.loader.grub2-theme.theme = lib.mkForce "whitesur";

  # Home Manager runs standalone via home-rebuild.sh; the embedded copy re-applied a stale generation at every boot.
  home-manager.users = lib.mkForce { };
}

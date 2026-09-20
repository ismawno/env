{ pkgs, ... }:

{
  # Ghostty ships xterm-ghostty only in the profile that installs it; system-wide it also resolves for root, sudo and ssh under other identities.
  environment.systemPackages = with pkgs; [ ghostty.terminfo ];
}

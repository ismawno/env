{ pkgs, ... }:

{
  _module.args.pkgs-unstable =
    import
      (builtins.fetchTree {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "02c087f3fe673c9e317f206a627cb6b910336dbe";
        narHash = "sha256-IoNisKcGbUjdd45qCqywGMCYmZ5EnkxezvLII0FWwNA=";
      })
      {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
}

{ pkgs, ... }:

{
  _module.args.pkgs-unstable =
    import
      (builtins.fetchTree {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = "b4fd65b198c599cbe814fcb9f42d25d021595ec9";
        narHash = "sha256-ilerN1WLSvF+HMjziC/Wv99J5y02maDH+6hZPwsORKg=";
      })
      {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
}

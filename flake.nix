{
  description = "NixOS + Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nvim.url = "github:ismawno/nvim";
    grub2-themes.url = "github:vinceliuice/grub2-themes";
  };

  outputs = { self, nixpkgs, home-manager, grub2-themes, ... }@inputs: {
    nixosConfigurations.nomad = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./hosts/nomad/configuration.nix
        grub2-themes.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.ismawno = {
            home.stateVersion = "25.05";
            imports = [ ./home.nix ./hosts/nomad/home.nix ];
            _module.args = { inherit inputs; };
          };
        }
      ];
    };
  };
}

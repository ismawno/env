{
  description = "NixOS + Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nvim.url = "github:ismawno/nvim";
    grub2-themes.url = "github:vinceliuice/grub2-themes";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, grub2-themes, nix-index-database, ...
    }@inputs:
    let
      system = "x86_64-linux";
      mkUserModule = { host, user }:
        let
          userPath = ./users/${user}/home.nix;
          userOverridePath = ./hosts/${host}/${user}.nix;
          hasOverride = builtins.pathExists userOverridePath;
        in if hasOverride then [ userPath userOverridePath ] else [ userPath ];

      mkHost = { host, users }:
        let
          hostPath = ./hosts/${host}/configuration.nix;

          mkUser = user: {
            home.stateVersion = "25.05";
            imports = mkUserModule {
              host = host;
              user = user;
            };
            _module.args = { inherit inputs; };
          };

          homeUsers = nixpkgs.lib.genAttrs users (u: mkUser u);

        in nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            hostPath
            nix-index-database.nixosModules.nix-index
            grub2-themes.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users = homeUsers;
            }
          ];
        };

      mkHome = { host, user }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { inherit system; };
          modules = mkUserModule {
            host = host;
            user = user;
          };
          extraSpecialArgs = { inherit inputs; };
        };

    in {
      nixosConfigurations = {
        nomad = mkHost {
          host = "nomad";
          users = [ "ismawno" ];
        };
      };
      homeConfigurations = {
        ismawno = mkHome {
          host = "nomad";
          user = "ismawno";
        };
      };
    };
}

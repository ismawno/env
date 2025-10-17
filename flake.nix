{

description = "NixOS Configuration";
inputs = {
nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
};

outputs = {self, nixpkgs}: {
nixosConfigurations = {
nomad = {nixpkgs.lib.nixosSystem = {
system = "x86_64-linux";
modules = [./configuration.nix
./hosts/nomad/hardware-configuration.nix];
};
};
};
};

}

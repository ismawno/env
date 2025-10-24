{
  description = "Generic dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "dev";

        buildInputs = with pkgs; [
          cmake
          clang-tools
          clang
          fmt
          hwloc
          linuxPackages.perf
          gnumake
          python313
        ];
      };
    };
}

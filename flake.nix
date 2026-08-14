{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      treefmt-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      imports = [
        treefmt-nix.flakeModule
      ];
      perSystem = { pkgs, lib, ... }: {
        treefmt.programs.nixfmt.enable = true;
        packages = lib.filterAttrs (_: v: lib.isDerivation v) (import ./default.nix { inherit pkgs; });
      };
      flake.lib = import ./lib { lib = nixpkgs.lib; };
      flake.nixosModules = import ./nixos-modules;
    };
}

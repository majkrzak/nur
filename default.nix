{ pkgs }:
{
  lib = import ./lib { inherit (pkgs) lib; };
  nixosModules = import ./nixos-modules;
  homeModules = import ./home-modules;

  compute-blade-dtbs = pkgs.callPackage ./pkgs/compute-blade-dtbs { inherit pkgs; };
}

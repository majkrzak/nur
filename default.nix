{ pkgs }:
{
  lib = import ./lib { inherit (pkgs) lib; };
  nixosModules = import ./nixos-modules;

  compute-blade-dtbs = pkgs.callPackage ./pkgs/compute-blade-dtbs { inherit pkgs; };
}

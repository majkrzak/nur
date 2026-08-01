{ pkgs }:
{
  lib = import ./lib { inherit (pkgs) lib; };
  nixosModules = import ./nixos-modules;
}

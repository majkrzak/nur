{ pkgs }:
{
  lib = import ./lib { inherit (pkgs) lib; };
}

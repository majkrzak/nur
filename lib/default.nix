{ lib }:
{
  genAddr = import ./genAddr.nix { inherit lib; };
}

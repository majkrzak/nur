{ lib }:
{
  genAddr = import ./genAddr.nix { inherit lib; };
  mkTraitOption = import ./mkTraitOption.nix { inherit lib; };
}

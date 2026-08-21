{ lib }:
{
  genAddr = import ./genAddr.nix { inherit lib; };
  mkVariantOption = import ./mkVariantOption.nix { inherit lib; };
}

{ inputs, ... }:
let
  inherit (builtins)
    replaceStrings
    baseNameOf
    listToAttrs
    ;
in
{
  flake.lib = inputs.import-tree (
    i:
    i.map (path: {
      name = replaceStrings [ ".nix" ] [ "" ] (baseNameOf path);
      value = (import path) { lib = inputs.nixpkgs.lib; };
    })
  ) (i: i.pipeTo listToAttrs) ../lib;
}

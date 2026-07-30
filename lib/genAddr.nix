{ lib, ... }:
let
  inherit (lib)
    hashString
    substring
    concatStringsSep
    genList
    ;
in
name:
concatStringsSep ":" (
  genList (i: substring (i * 4) 4 ("fc" + substring 0 30 (hashString "sha256" name))) 8
)

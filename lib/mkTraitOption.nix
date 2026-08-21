{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    optionalAttrs
    ;
in
{
  source,
  enableNixosModule ? true,
  enableHomeModules ? true,
}:
mkOption {
  type = types.str;
  apply =
    v:
    (optionalAttrs enableNixosModule { inherit (source.${v}) nixosModules; })
    // (optionalAttrs enableHomeModules { inherit (source.${v}) homeModules; });
}

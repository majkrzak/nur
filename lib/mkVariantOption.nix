{
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    toList
    optionalAttrs
    id
    ;
  inherit (lib.types)
    nullOr
    listOf
    str
    ;
in
{
  source,
  enableNixosModules ? true,
  enableHomeModules ? true,
  nullable ? false,
  multiple ? false,
  description ? null,
  example ? null,
  default ? null,
  visible ? true,
  internal ? false,
  readOnly ? false,
}:
mkOption {
  type = (if nullable then nullOr else id) ((if multiple then listOf else id) str);
  apply =
    value:
    optionalAttrs (value != null) (
      optionalAttrs enableNixosModules {
        nixosModules.imports = map (name: source.${name}.nixosModules) (toList value);
      }
      // optionalAttrs enableHomeModules {
        homeModules.imports = map (name: source.${name}.homeModules) (toList value);
      }
    );
  inherit
    description
    example
    default
    visible
    internal
    readOnly
    ;
}

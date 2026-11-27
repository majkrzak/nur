{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    attrValues
    concatMapStrings
    escapeShellArg
    mkIf
    ;
  inherit (lib.types)
    attrsOf
    submodule
    str
    ;
  cfg = config.services.garage;
in
{
  options.services.garage = {
    ensureBuckets = mkOption {
      type = attrsOf (
        submodule (
          { name, ... }: {
            options = {
              name = mkOption {
                type = str;
                readOnly = true;
                default = name;
              };
            };
          }
        )
      );
      default = { };
    };
    ensureKeys = mkOption {
      type = attrsOf (
        submodule (
          { name, ... }: {
            options = {
              name = mkOption {
                type = str;
                readOnly = true;
                default = name;
              };
            };
          }
        )
      );
      default = { };
    };
  };
  config = mkIf (cfg.enable && (cfg.ensureBuckets != { } || cfg.ensureKeys != { })) {
    systemd.services.garage-ensure = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "garage.service" ];
      after = [ "garage.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        cfg.package
      ];
      script = ''
        ${concatMapStrings (bucket: ''
          if ! garage bucket info ${escapeShellArg bucket.name} >/dev/null 2>&1; then
            garage bucket create ${escapeShellArg bucket.name} >/dev/null
          fi
        '') (attrValues cfg.ensureBuckets)}
        ${concatMapStrings (key: ''
          if ! garage key info ${escapeShellArg key.name} >/dev/null 2>&1; then
            garage key create ${escapeShellArg key.name} >/dev/null
          fi
        '') (attrValues cfg.ensureKeys)}
      '';
    };
  };
}

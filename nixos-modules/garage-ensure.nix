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
  options.services.garage.ensureKeys = mkOption {
    type = attrsOf (
      submodule (
        { name, ... }: {
          options = {
            name = mkOption {
              type = str;
              default = name;
            };
          };
        }
      )
    );
    default = { };
  };
  config = mkIf (cfg.enable && cfg.ensureKeys != { }) {
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
        ${concatMapStrings (key: ''
          if ! garage key info ${escapeShellArg key.name} --key-id >/dev/null 2>&1; then
            garage key create ${escapeShellArg key.name} >/dev/null
          fi
        '') (attrValues cfg.ensureKeys)}
      '';
    };
  };
}

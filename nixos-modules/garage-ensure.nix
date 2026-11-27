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
    optionalString
    ;
  inherit (lib.types)
    attrsOf
    submodule
    str
    bool
    nullOr
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
              buckets = mkOption {
                type = attrsOf (
                  submodule (
                    { name, ... }: {
                      options = {
                        name = mkOption {
                          type = str;
                          readOnly = true;
                          default = name;
                        };
                        alias = mkOption {
                          type = nullOr str;
                          default = null;
                        };
                        read = mkOption {
                          type = nullOr bool;
                          default = null;
                        };
                        write = mkOption {
                          type = nullOr bool;
                          default = null;
                        };
                        owner = mkOption {
                          type = nullOr bool;
                          default = null;
                        };
                      };
                    }
                  )
                );
              };
            };
          }
        )
      );
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
          ${concatMapStrings (
            bucket:
            optionalString (bucket.alias != null) ''
              garage bucket alias ${escapeShellArg bucket.name} ${escapeShellArg bucket.alias} --local ${escapeShellArg key.name} >/dev/null
            ''
            + optionalString (bucket.read == true || bucket.write == true || bucket.owner == true) ''
              garage bucket allow ${
                optionalString (bucket.read == true) "--read"
                + optionalString (bucket.write == true) "--write"
                + optionalString (bucket.owner == true) "--owner"
              } ${escapeShellArg bucket.name} --key ${escapeShellArg key.name} >/dev/null
            ''
            + optionalString (bucket.read == false || bucket.write == false || bucket.owner == false) ''
              garage bucket deny ${
                optionalString (bucket.read == false) "--read"
                + optionalString (bucket.write == false) "--write"
                + optionalString (bucket.owner == false) "--owner"
              } ${escapeShellArg bucket.name} --key ${escapeShellArg key.name} >/dev/null
            ''
          ) (attrValues key.buckets)}
        '') (attrValues cfg.ensureKeys)}
      '';
    };
  };
}

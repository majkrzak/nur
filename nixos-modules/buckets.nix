{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    mapAttrs'
    listToAttrs
    filterAttrs
    mkIf
    nameValuePair
    ;
  inherit (lib.types)
    str
    path
    nullOr
    attrsOf
    submodule
    ;
  sopsCfg = config.sops;
  cfg = filterAttrs (_name: fs: (fs.bucket.name != null)) config.fileSystems;
in
{
  options.fileSystems = mkOption {
    type = attrsOf (submodule [
      (
        { config, ... }:
        let
          cfg' = config.bucket;
        in
        {
          options.bucket = {
            name = mkOption {
              type = nullOr str;
              default = null;
              description = "Name of the S3 bucket.";
            };
            endpoint = mkOption {
              type = str;
              description = "Endpoint of the S3 service.";
            };
            access_key_id = mkOption {
              type = str;
              description = "Access key identifier.";
            };
            secret_access_key = mkOption {
              type = path;
              description = "Access key secret SOPS binnary file.";
            };
            region = mkOption {
              type = str;
              description = "S3 region.";
            };
          };
          config = mkIf (cfg'.name != null) {
            device = "s3:${cfg'.name}";
            fsType = "rclone";
            options = [
              "config=${sopsCfg.templates."${cfg'.name}-rclone.conf".path}"
            ];
          };
        }
      )
    ]);
  };
  config = {
    sops.secrets = mapAttrs' (
      _: fs:
      nameValuePair fs.bucket.access_key_id {
        sopsFile = fs.bucket.secret_access_key;
        format = "binary";
        mode = "0400";
      }
    ) cfg;
    sops.templates = mapAttrs' (
      _: fs:
      nameValuePair "${fs.bucket.name}-rclone.conf" {
        content = ''
          [s3]
          type = s3
          provider = Other
          endpoint = ${fs.bucket.endpoint}
          access_key_id = ${fs.bucket.access_key_id}
          secret_access_key = ${config.sops.placeholder.${fs.bucket.access_key_id}}
          region = ${fs.bucket.region}
          env_auth = false
        '';
      }
    ) cfg;
  };
}

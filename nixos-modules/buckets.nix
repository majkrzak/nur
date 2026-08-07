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
    listToAttrs
    mkIf
    filter
    unique
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

  buckets = unique (
    filter (bucket: bucket.name != null) (
      (map (fs: fs.bucket) (attrValues config.fileSystems))
      ++ (map (cert: cert.bucket) (attrValues config.security.acme.certs))
    )
  );
  bucketOps = {
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
          options.bucket = bucketOps;
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
  options.security.acme.certs = mkOption {
    type = attrsOf (submodule [
      (
        { config, name, ... }:
        let
          cfg' = config.bucket;
        in
        {
          options.bucket = bucketOps;
          config = mkIf (cfg'.name != null) {
            postRun = ''
              ${pkgs.rclone}/bin/rclone \
                copy . s3:certs/${name} \
                --config=${sopsCfg.templates."${cfg'.name}-rclone.conf".path}
            '';
          };
        }
      )
    ]);
  };
  config = {
    environment.systemPackages = with pkgs; [ rclone ];
    sops.secrets = listToAttrs (
      map (
        bucket:
        nameValuePair bucket.access_key_id {
          sopsFile = bucket.secret_access_key;
          format = "binary";
          mode = "0400";
        }
      ) buckets
    );
    sops.templates = listToAttrs (
      map (
        bucket:
        nameValuePair "${bucket.name}-rclone.conf" {
          content = ''
            [s3]
            type = s3
            provider = Other
            endpoint = ${bucket.endpoint}
            access_key_id = ${bucket.access_key_id}
            secret_access_key = ${config.sops.placeholder.${bucket.access_key_id}}
            region = ${bucket.region}
            env_auth = false
          '';
        }
      ) buckets
    );
  };
}

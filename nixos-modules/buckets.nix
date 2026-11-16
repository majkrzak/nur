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
    optionalString
    ;
  inherit (lib.types)
    str
    path
    port
    bool
    nullOr
    attrsOf
    submodule
    ;
  sopsCfg = config.sops;

  webdavServices = filter (svc: svc.bucket.name != null) (attrValues config.services.webdav);

  buckets = unique (
    filter (bucket: bucket.name != null) (
      (map (fs: fs.bucket) (attrValues config.fileSystems))
      ++ (map (cert: cert.bucket) (attrValues config.security.acme.certs))
      ++ (map (svc: svc.bucket) webdavServices)
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
  options.services.webdav = mkOption {
    type = attrsOf (submodule [
      (
        { ... }:
        {
          options = {
            bucket = bucketOps;
            listen = mkOption {
              type = str;
              default = "[::1]";
              description = "Address to serve the WebDAV endpoint on.";
            };
            port = mkOption {
              type = port;
              default = 8098;
              description = "Port to serve the WebDAV endpoint on.";
            };
            prefix = mkOption {
              type = nullOr str;
              default = null;
              description = "URL prefix passed as rclone --baseurl.";
            };
            readOnly = mkOption {
              type = bool;
              default = true;
              description = "Serve the bucket read-only.";
            };
          };
        }
      )
    ]);
    default = { };
    description = "Serve S3 buckets over WebDAV using rclone.";
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
    systemd.services = listToAttrs (
      map (
        svc:
        nameValuePair "webdav-${svc.bucket.name}" {
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          serviceConfig = {
            Restart = "on-failure";
            ExecStart = ''
              ${pkgs.rclone}/bin/rclone \
                --config ${sopsCfg.templates."${svc.bucket.name}-rclone.conf".path} \
                serve webdav s3:${svc.bucket.name} \
                --addr "${svc.listen}:${toString svc.port}" \
                ${optionalString (svc.prefix != null) "--baseurl ${svc.prefix}"} \
                ${optionalString svc.readOnly "--read-only"} \
                --no-modtime \
                --vfs-fast-fingerprint
            '';
          };
        }
      ) webdavServices
    );
  };
}

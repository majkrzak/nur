{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    mkIf
    removePrefix
    hasPrefix
    filter
    unique
    attrValues
    throwIfNot
    ;
  inherit (lib.types) nullOr str;
  cfg = config.xdg.userDirs;
in
{
  options = {
    xdg.userDirs.persist = mkOption {
      type = nullOr str;
      default = null;
      description = "Persistent storage location for the XDG user directories.";
    };
  };
  config = mkIf (cfg.persist != null) {
    home.persistence.${cfg.persist}.directories =
      map
        (
          p:
          throwIfNot (hasPrefix "${config.home.homeDirectory}/" p)
            "xdg.userDirs.persist: '${p}' is not under '${config.home.homeDirectory}/}'"
            (removePrefix "${config.home.homeDirectory}/" p)
        )
        (
          unique (
            filter (p: p != null && p != "") (
              [
                cfg.desktop
                cfg.documents
                cfg.download
                cfg.music
                cfg.pictures
                cfg.projects
                cfg.publicShare
                cfg.templates
                cfg.videos
              ]
              ++ attrValues cfg.extraConfig
            )
          )
        );
  };
}

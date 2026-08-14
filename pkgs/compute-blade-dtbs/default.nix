{
  lib,
  pkgs,
  kernelPackages ? pkgs.linuxPackages,
}:
let
  kernel = kernelPackages.kernel;
  kernelDts = pkgs.runCommand "kernelDts" { } ''
    mkdir -p "$out"
    tar xv \
      -f ${kernel.src} \
      -C "$out" \
      --strip-components=1 \
      "linux-${kernel.modDirVersion}/arch/arm/boot/dts"
  '';

  dtsFiles = lib.filter (f: lib.hasSuffix ".dts" f) (builtins.attrNames (builtins.readDir ./dts));

  dtbs = map (f: {
    name = lib.removeSuffix ".dts" f;
    drv = pkgs.deviceTree.compileDTS {
      name = lib.removeSuffix ".dts" f;
      dtsFile = ./dts/${f};
      includePaths = [
        "${lib.getDev kernel}/lib/modules/${kernel.modDirVersion}/source/scripts/dtc/include-prefixes"
        "${kernelDts}/arch/arm/boot/dts"
        "${kernelDts}/arch/arm/boot/dts/broadcom"
      ];
    };
  }) dtsFiles;
in
pkgs.runCommandLocal "compute-blade-dtbs" { } ''
  mkdir -p "$out"
  ${lib.concatMapStringsSep "\n" (dtb: "cp ${dtb.drv} $out/${dtb.name}.dtb") dtbs}
''

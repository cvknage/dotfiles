{pkgs, ...}: let
  harmonyEnv = pkgs.buildFHSEnv {
    name = "checkpoint-harmony-endpoint-env";

    targetPkgs = pkgs:
      with pkgs; [
        # core runtime
        glibc
        stdenv.cc.cc
        zlib
        openssl
        pam
        libgcc

        # common userland tools many install scripts expect
        coreutils
        bash
        findutils
        gnugrep
        gawk
        gnused
        procps
        util-linux
        systemd
      ];

    runScript = "bash";
    extraOutputsToInstall = ["dev" "out"];
  };
in {
  environment.systemPackages = [
    harmonyEnv
  ];
}

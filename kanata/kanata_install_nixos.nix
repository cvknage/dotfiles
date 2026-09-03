{
  lib,
  pkgs,
  ...
}: let
  kanata = import ./kanata_linux.nix {inherit pkgs;};
in {
  hardware.uinput.enable = true;
  boot.kernelModules = ["uinput"];
  users.groups.uinput = {};

  services.udev.extraRules = ''
    SUBSYSTEM=="misc", KERNEL=="uinput", TAG+="systemd", ENV{SYSTEMD_WANTS}="uinput-perms.service"
  '';

  systemd.services.uinput-perms = {
    description = "Set /dev/uinput to 0660 root:uinput";
    serviceConfig =
      {
        Type = "oneshot";
        ExecStart = [
          "/run/current-system/sw/bin/chgrp uinput /dev/uinput"
          "/run/current-system/sw/bin/chmod 0660 /dev/uinput"
        ];
        RemainAfterExit = true;

        # Hardening
        ReadWritePaths = ["/dev/uinput"]; # only /dev/uinput is writable
        CapabilityBoundingSet = ["CAP_CHOWN" "CAP_FOWNER"]; # allow only chown/chmod
        SystemCallFilter = ["@system-service" "@file-system" "@chown"]; # allow basic service, file, and chown syscalls
      }
      // kanata.sharedHardening;
  };

  systemd.services.kanata = lib.recursiveUpdate kanata.kanataService {
    after = ["dev-uinput.device" "uinput-perms.service"];
    wants = ["uinput-perms.service"];
  };
}

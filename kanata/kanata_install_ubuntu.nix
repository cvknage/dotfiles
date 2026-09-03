# Ubuntu owns the kernel, kmod, and udev. System Manager owns the uinput group,
# the udev rule, the module load, and the kanata service.
{
  lib,
  pkgs,
  ...
}: let
  kanata = import ./kanata_linux.nix {inherit pkgs;};
in {
  environment.systemPackages = [pkgs.kanata];

  environment.etc = {
    # systemd-sysusers only adds the group; it never touches Ubuntu's own
    # groups, unlike the userborn tier disabled in the host configuration.
    "sysusers.d/uinput.conf".text = "g uinput -\n";
    "modules-load.d/uinput.conf".text = "uinput\n";
    "udev/rules.d/99-uinput.rules".text = kanata.uinputUdevRule;
  };

  # Applies the module and the rule without a reboot, using Ubuntu's own tools.
  systemd.services.uinput-setup = {
    description = "Load the uinput module and apply its udev rule";
    wantedBy = ["multi-user.target"];
    after = ["systemd-sysusers.service"];
    before = ["kanata.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "/usr/sbin/modprobe uinput"
        "/usr/bin/udevadm control --reload-rules"
        "/usr/bin/udevadm trigger --subsystem-match=misc --sysname-match=uinput"
      ];
    };
  };

  systemd.services.kanata = lib.recursiveUpdate kanata.kanataService {
    after = ["dev-uinput.device" "uinput-setup.service"];
    wants = ["uinput-setup.service"];
  };
}

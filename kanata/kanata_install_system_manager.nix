# For the System Manager tier on any distro. The host owns the kernel, kmod and
# udev; System Manager owns the uinput group, the udev rule, the module load,
# and the kanata service.
{
  lib,
  pkgs,
  ...
}: let
  kanata = import ./kanata_linux.nix {inherit pkgs;};

  # The host's own kmod and udev, found by PATH rather than absolute path:
  # Fedora merged /usr/sbin into /usr/bin, Ubuntu has not.
  uinputSetup = pkgs.writeShellScript "uinput-setup" ''
    PATH=/usr/sbin:/usr/bin:/sbin:/bin
    modprobe uinput
    udevadm control --reload-rules
    udevadm trigger --subsystem-match=misc --sysname-match=uinput
  '';
in {
  environment.systemPackages = [pkgs.kanata];

  environment.etc = {
    # systemd-sysusers only adds the group; it never touches the host's own
    # groups, unlike the userborn tier disabled in the host configuration.
    "sysusers.d/uinput.conf".text = "g uinput -\n";
    "modules-load.d/uinput.conf".text = "uinput\n";
    "udev/rules.d/99-uinput.rules".text = kanata.uinputUdevRule;
  };

  # Applies the module and the rule without a reboot.
  systemd.services.uinput-setup = {
    description = "Load the uinput module and apply its udev rule";
    wantedBy = ["multi-user.target"];
    after = ["systemd-sysusers.service"];
    before = ["kanata.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${uinputSetup}";
    };
  };

  systemd.services.kanata = lib.recursiveUpdate kanata.kanataService {
    after = ["dev-uinput.device" "uinput-setup.service"];
    wants = ["uinput-setup.service"];
  };
}

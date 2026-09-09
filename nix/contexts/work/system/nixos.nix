# Work-role system bits for NixOS hosts.
{user, ...}: {
  # System identity: the things that change on reinstall or by preference,
  # not with the hardware.
  networking.hostName = "penguin-tuxedo";
  system.stateVersion = "24.11";

  # Enable docker
  virtualisation.docker.enable = true;

  users.users.${user}.extraGroups = ["docker"];
}

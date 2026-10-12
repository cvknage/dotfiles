# Work-role system bits for NixOS hosts.
{user, ...}: {
  imports = [../../../modules/shared/vpn/snx-rs.nix];

  # System identity: the things that change on reinstall or by preference,
  # not with the hardware.
  networking.hostName = "penguin-tuxedo";
  system.stateVersion = "24.11";

  # Enable docker
  virtualisation.docker.enable = true;

  users.users.${user}.extraGroups = ["docker"];

  # Strict reverse-path filtering drops the snx-rs IPsec tunnel's keepalive
  # traffic; this is upstream's own recommended NixOS setting (docs/nixos.md).
  networking.firewall.checkReversePath = "loose";
}

# System Manager twin of nixos/agents/docker.nix. Docker is host-managed here, so there is no
# virtualisation.docker.enable to gate on; the shared unit gates on /run/docker.sock at runtime.
{
  lib,
  pkgs,
  user,
  ...
}: let
  homeDirectory = "/home/${user}";
  policy = import ../../../lib/agents/policy/default.nix {
    inherit homeDirectory lib;
    isDarwin = false;
    xdgConfigHome = "${homeDirectory}/.config";
  };
in {
  systemd.services.docker-agent-proxy = import ../../../lib/agents/docker-proxy-unit.nix {
    inherit lib pkgs policy user;
  };
}

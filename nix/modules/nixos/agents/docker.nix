# docker/containerd skip mount-namespace hardening (breaks all container creation, confirmed on the Fedora sibling); docker-agent-proxy enforces the denylist instead, at its own socket.
{
  config,
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
in
  lib.mkIf config.virtualisation.docker.enable {
    systemd.services.docker-agent-proxy = import ../../../lib/agents/docker-proxy-unit.nix {
      inherit lib pkgs policy user;
    };
  }

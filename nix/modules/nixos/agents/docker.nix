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
  dockerAgentProxy = pkgs.callPackage ../../../pkgs/docker-agent-proxy {};
in
  lib.mkIf config.virtualisation.docker.enable {
    systemd.services.docker-agent-proxy = {
      description = "Docker Engine API proxy enforcing the agent sandbox's bind-mount denylist";
      after = ["docker.socket" "docker.service"];
      wants = ["docker.socket" "docker.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs [
          (lib.getExe dockerAgentProxy)
          "-listen"
          policy.dockerProxySocketPath
          "-upstream"
          "/run/docker.sock"
          "-group"
          "docker"
          "-denied"
          (lib.concatStringsSep "," policy.deniedPaths)
        ];
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  }

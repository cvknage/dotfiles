# Docker is host-managed; System Manager only owns these drop-ins. docker/containerd skip mount-namespace hardening (breaks all container creation), so docker-agent-proxy enforces the denylist instead, at its own socket.
{
  lib,
  pkgs,
  user,
  ...
}: let
  homeDirectory = "/home/${user}";
  policy = import ../../lib/agents/policy/paths.nix {
    inherit lib homeDirectory;
    isDarwin = false;
    xdgConfigHome = "${homeDirectory}/.config";
  };
  dockerAgentProxy = pkgs.callPackage ../../pkgs/docker-agent-proxy {};
in {
  environment.etc = {
    # Force overlay2: Fedora's moby-engine default containerd snapshotter extracts kind's node images incorrectly.
    "docker/daemon.json".text = builtins.toJSON {
      features.containerd-snapshotter = false;
    };
  };

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

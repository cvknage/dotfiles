# The docker-agent-proxy systemd unit, shared verbatim by the NixOS and System Manager tiers.
#
# The denylist is static except for /run/user/<uid>, whose uid no tier resolves while the flake
# evaluates (see runtimeCredentialDirs in policy/paths.nix). Resolving it in ExecStart means the
# unit's view of the uid is the host's actual one; an unknown user aborts under errexit rather
# than quietly denying somebody else's runtime directory.
{
  lib,
  pkgs,
  policy,
  user,
}: let
  dockerAgentProxy = pkgs.callPackage ../../pkgs/docker-agent-proxy {};

  # Escaped as one literal so a path that ever contains a shell metacharacter cannot drop
  # silently out of the list; $uid stays the only live expansion. dockerDeniedPaths (not
  # deniedPaths) carries the container-only denies -- see policy/paths.nix.
  staticDenied = lib.escapeShellArg (lib.concatStringsSep "," policy.dockerDeniedPaths);
  runtimeDenied = lib.concatMapStrings (dir: ",/run/user/$uid/${dir}") policy.runtimeCredentialDirs;

  startProxy = pkgs.writeShellApplication {
    name = "docker-agent-proxy-start";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      uid="$(id -u ${lib.escapeShellArg user})"
      denied=${staticDenied}

      exec ${lib.getExe dockerAgentProxy} \
        -listen ${lib.escapeShellArg policy.dockerProxySocketPath} \
        -upstream /run/docker.sock \
        -group docker \
        -denied "$denied${runtimeDenied}"
    '';
  };
in {
  description = "Docker Engine API proxy enforcing the agent sandbox's bind-mount denylist";
  after = ["docker.socket" "docker.service"];
  wants = ["docker.socket" "docker.service"];
  wantedBy = ["multi-user.target"];
  # System Manager has no virtualisation.docker.enable to gate on (docker is host-managed), and
  # the Fedora bootstrap even applies this unit before it enables docker; skip cleanly until the
  # daemon socket exists rather than run against a missing upstream.
  unitConfig.ConditionPathExists = "/run/docker.sock";
  serviceConfig = {
    Type = "simple";
    ExecStart = lib.getExe startProxy;
    Restart = "on-failure";
    RestartSec = 1;
  };
}

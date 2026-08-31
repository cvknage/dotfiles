# Give the rootful development daemon the same private-path boundary as the
# agents while preserving its normal socket, networking, devices, and storage.
{
  config,
  lib,
  user,
  ...
}: let
  homeDirectory = "/home/${user}";
  policy = import ./policy.nix {
    inherit homeDirectory lib;
    isDarwin = false;
    xdgConfigHome = "${homeDirectory}/.config";
  };
  restrictedServiceConfig = {
    PrivateMounts = true;
    ProtectHome = "tmpfs";
    BindPaths = policy.workspaceRoots;
    InaccessiblePaths = map (path: "-${path}") policy.deniedPaths;
  };
in
  lib.mkIf config.virtualisation.docker.enable {
    # Docker delegates container setup and bind mounts to containerd, so both
    # services must receive the same filesystem view.
    systemd.services.docker.serviceConfig = restrictedServiceConfig;
    systemd.services.containerd.serviceConfig = restrictedServiceConfig;
  }

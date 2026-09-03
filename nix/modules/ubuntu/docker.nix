# Docker is installed and updated by Ubuntu. System Manager owns only these
# systemd drop-ins; defining `systemd.services.docker` here would replace
# Ubuntu's unit and drop its ExecStart.
{
  lib,
  user,
  ...
}: let
  homeDirectory = "/home/${user}";
  policy = import ../agents/policy.nix {
    inherit lib homeDirectory;
    isDarwin = false;
    xdgConfigHome = "${homeDirectory}/.config";
  };
  restrictedFilesystemView = ''
    [Service]
    PrivateMounts=true
    ProtectHome=tmpfs
    ${lib.concatMapStringsSep "\n" (path: "BindPaths=${path}") policy.workspaceRoots}
    ${lib.concatMapStringsSep "\n" (path: "InaccessiblePaths=-${path}") policy.deniedPaths}
  '';
in {
  environment.etc = {
    "systemd/system/docker.service.d/10-agent-boundary.conf".text = restrictedFilesystemView;
    "systemd/system/containerd.service.d/10-agent-boundary.conf".text = restrictedFilesystemView;
  };
}

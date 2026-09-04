{
  inputs,
  lib,
  pkgs,
  self,
  user,
  ...
}: let
  # The GPU library set Home Manager builds for this host. Declaring the symlink
  # below is what Home Manager's `sudo non-nixos-gpu-setup` would do by hand;
  # owning it here re-applies it on every rebuild and keeps it in the profile,
  # so it is garbage-collected with the generation that needs it.
  gpuDrivers = self.homeConfigurations."${user}@work".config.targets.genericLinux.gpu.drivers;
in {
  imports = [
    ../../../kanata/kanata_install_system_manager.nix
    ../../modules/system-manager/agents/default.nix
    ../../modules/system-manager/docker.nix
    ../../modules/system-manager/environment-path.nix
  ];

  nixpkgs = {
    config.allowUnfree = true;
    hostPlatform = "x86_64-linux";
  };

  # Nix is installed and upgraded by nix-installer. Do not let System Manager
  # replace that installation or its daemon configuration.
  nix.enable = false;

  # Ubuntu and Red Hat IdM own users and groups. System Manager's default
  # userborn tier would try to align groups like input, kvm, and render with
  # nixpkgs GIDs, which do not match Ubuntu's.
  services.userborn.enable = false;

  environment.systemPackages = with pkgs; [
    bubblewrap
    git
    gocryptfs
    gnupg

    # NixOS gets this from programs.localsend, which also opens port 53317.
    # System Manager only mocks networking.firewall, so if `sudo ufw status`
    # reports active, open the port with Ubuntu's own tool (both protocols):
    #   sudo ufw allow 53317 comment 'localsend'
    localsend
  ];

  # Nix-built GPU apps link against this path, which only NixOS provides.
  systemd.tmpfiles.settings."10-gpu"."/run/opengl-driver"."L+".argument = "${gpuDrivers}";

  systemd.tmpfiles.settings."10-workspace" = {
    "/home/${user}/code".d = {
      mode = "0755";
      user = user;
      group = "${user}";
    };
    "/home/${user}/.mcp-auth".d = {
      mode = "0700";
      user = user;
      group = "${user}";
    };
  };
}

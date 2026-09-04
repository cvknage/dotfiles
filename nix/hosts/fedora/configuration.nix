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

  # System Manager only asserts support for nixos, ubuntu and debian. Fedora is
  # untested upstream, so this tier is experimental here even though the modules
  # it uses are distro-agnostic.
  system-manager.allowAnyDistro = true;

  # Fedora's nix package installs and upgrades Nix. Do not let System Manager
  # replace that installation or its daemon configuration.
  nix.enable = false;

  # Fedora and Red Hat IdM own users and groups. System Manager's default
  # userborn tier would try to align groups like input, kvm, and render with
  # nixpkgs GIDs, which do not match Fedora's.
  services.userborn.enable = false;

  # Matches homes/work/default.nix's GNOME dconf input source, so the GDM
  # greeter and console (which don't read per-user dconf) use the same
  # AltGr layout kanata's Linux config assumes (kanata/kanata_us.kbd).
  environment.etc."X11/xorg.conf.d/00-keyboard.conf".text = ''
    Section "InputClass"
            Identifier "system-keyboard"
            MatchIsKeyboard "on"
            Option "XkbLayout" "us"
            Option "XkbModel" "pc105"
            Option "XkbVariant" "mac"
    EndSection
  '';

  environment.systemPackages = with pkgs; [
    bubblewrap
    git
    gocryptfs
    gnupg

    # NixOS gets this from programs.localsend, which also opens port 53317.
    # System Manager only mocks networking.firewall, and Fedora runs firewalld
    # by default, so the port has to be opened with Fedora's own tool:
    #   sudo firewall-cmd --permanent --add-port=53317/tcp
    #   sudo firewall-cmd --permanent --add-port=53317/udp
    #   sudo firewall-cmd --reload
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

# Only for standalone Home Manager on a distro other than NixOS. It puts the
# Nix profile's share directory on XDG_DATA_DIRS through
# ~/.config/environment.d, which is what makes GUI apps installed here appear
# in the desktop's launcher. Never import this from the NixOS module path.
{
  config,
  lib,
  ...
}: {
  targets.genericLinux.enable = true;

  # The module above sources nix.sh from .bashrc, and nix.sh has no re-source
  # guard, so every interactive shell re-prepends its bin and re-appends its
  # share directories: home-manager#8076. Runs last and keeps the first
  # occurrence of each entry, so the session's own ordering survives.
  programs.bash.initExtra = lib.mkAfter ''
    __hm_dedup_path_var() {
      local var="$1" out="" entry
      local IFS=":"
      for entry in ''${!var}; do
        [ -n "$entry" ] || continue
        case ":$out:" in
          *":$entry:"*) ;;
          *) out="''${out:+$out:}$entry" ;;
        esac
      done
      export "$var=$out"
    }
    __hm_dedup_path_var PATH
    __hm_dedup_path_var XDG_DATA_DIRS
    unset -f __hm_dedup_path_var
  '';

  # The other half of home-manager#8076 is ordering: the module hardcodes
  # xdg.systemDirs.data with the Nix profile first and no Flatpak exports.
  # Those are inherited at the end of XDG_DATA_DIRS, so Flatpak apps stay
  # visible and only lose precedence to Nix. The option does merge, so to
  # reverse that: xdg.systemDirs.data = lib.mkBefore ["<flatpak exports>"];

  # This also enables targets.genericLinux.gpu by default, which is what keeps
  # GPU-accelerated Nix apps from crashing: they link against /run/opengl-driver,
  # which only NixOS provides. Home Manager cannot create it without root, so it
  # prints a `sudo non-nixos-gpu-setup` command on every switch that needs one.
  # A System Manager tier owns that symlink instead, so the command is only
  # needed on hosts running Home Manager with no system tier.
  #
  # On a host using the proprietary Nvidia driver, also set:
  #   targets.genericLinux.gpu.nvidia.enable = true;
  #   targets.genericLinux.gpu.nvidia.version = "<host driver version>";
  #   targets.genericLinux.gpu.nvidia.sha256 = "<hash of that driver>";
  #
  # The version must match the host's driver exactly, or the libraries fail to
  # load against the running kernel module. Read it from the host:
  #   nvidia-smi --query-gpu=driver_version --format=csv,noheader
  #
  # Then hash the matching release, with Linux-aarch64 in both places on ARM:
  #   VERSION=<the version above>
  #   nix store prefetch-file --json \
  #     "https://download.nvidia.com/XFree86/Linux-x86_64/$VERSION/NVIDIA-Linux-x86_64-$VERSION.run" \
  #     | jq -r .hash

  # Ghostty's DBusActivatable=true routes launches through systemd's UnitPath,
  # which never picks up the Home Manager profile (locked in at manager
  # startup, before environment.d ever runs). Drop it so the icon just execs
  # directly.
  home.file."${config.xdg.dataHome}/applications/com.mitchellh.ghostty.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Name=Ghostty
    Type=Application
    Comment=A terminal emulator
    TryExec=ghostty
    Exec=ghostty --gtk-single-instance=true
    Icon=com.mitchellh.ghostty
    Categories=System;TerminalEmulator;
    Keywords=terminal;tty;pty;
    StartupNotify=true
    StartupWMClass=com.mitchellh.ghostty
    Terminal=false
    Actions=new-window;
    X-GNOME-UsesNotifications=true
    X-TerminalArgExec=-e
    X-TerminalArgTitle=--title=
    X-TerminalArgAppId=--class=
    X-TerminalArgDir=--working-directory=
    X-TerminalArgHold=--wait-after-command
    X-KDE-Shortcuts=Ctrl+Alt+T

    [Desktop Action new-window]
    Name=New Window
    Exec=ghostty --gtk-single-instance=true
  '';
}

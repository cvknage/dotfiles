# Shared helpers for the agent sandbox launchers.
{
  lib,
  pkgs,
}: let
  # Baseline for every agent; project-specific tools arrive through the inherited environment.
  agentTools = with pkgs; [
    ast-grep
    bat
    coreutils
    diffutils
    fd
    file
    findutils
    gawk
    git
    gnugrep
    gnused
    jq
    patch
    ripgrep
    tree
    tree-sitter
    yq-go
  ];

  mkLaunchSetup = agent: profile: let
    launchRoots = lib.escapeShellArgs profile.launchRoots;
  in ''
    cwd_real="$(realpath "$PWD")"
    in_scope=false
    for root in ${launchRoots}; do
      [ -e "$root" ] || continue
      root_real="$(realpath "$root")"
      case "$cwd_real" in
        "$root_real"|"$root_real"/*) in_scope=true ;;
      esac
    done
    if [ "$in_scope" != true ]; then
      echo "${agent} sandbox: start the agent inside a managed workspace or its own config directory" >&2
      exit 2
    fi

    ${lib.concatMapStringsSep "\n" (path: "mkdir -p ${lib.escapeShellArg path}") profile.ensureDirectories}
    ${lib.concatMapStringsSep "\n" (path: ''
        mkdir -p ${lib.escapeShellArg (builtins.dirOf path)}
        touch ${lib.escapeShellArg path}
      '')
      profile.ensureFiles}
  '';
in {
  inherit
    agentTools
    mkLaunchSetup
    ;
}

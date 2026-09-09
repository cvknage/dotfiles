# Shared helpers for the agent sandbox launchers.
{
  lib,
  pkgs,
}: let
  # Stable baseline available to every agent independently of the developer's
  # interactive shell. Project-specific SDKs and tools still come from direnv.
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

  direnvRunner = pkgs.writeShellApplication {
    name = "agent-direnv-runner";
    runtimeInputs = [pkgs.direnv pkgs.jq];
    text = ''
      cwd="''${1-}"
      target="''${2-}"
      if [ -z "$cwd" ] || [ -z "$target" ]; then
        echo "agent direnv runner: working directory and target are required" >&2
        exit 2
      fi
      shift 2

      status="$(direnv status --json 2>/dev/null || true)"
      if printf '%s' "$status" | jq -e '.state.foundRC == null' >/dev/null 2>&1; then
        exec "$target" "$@"
      fi
      if printf '%s' "$status" | jq -e '.state.foundRC.allowed == 0' >/dev/null 2>&1; then
        exec direnv exec "$cwd" "$target" "$@"
      fi

      echo "agent launcher: the project environment is not allowed; starting with the inherited environment" >&2
      echo "review the .envrc and run 'direnv allow' to enable project-local tools" >&2
      exec "$target" "$@"
    '';
  };

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
    direnvRunner
    mkLaunchSetup
    ;
}

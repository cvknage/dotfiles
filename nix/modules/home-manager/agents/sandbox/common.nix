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
    go
    jq
    patch
    ripgrep
    tree
    tree-sitter
    yq-go
  ];

  herdrAgentProxy = pkgs.callPackage ../../../../pkgs/herdr-agent-proxy {};
  openUrlProxy = pkgs.callPackage ../../../../pkgs/open-url-proxy {};
  hostOpener =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "open"
    else "xdg-open";

  # alreadySandboxedCheck: per-platform shell expression for "already inside a jail", not a plain
  # (forgeable) env var.
  mkLaunchSetup = agent: profile: alreadySandboxedCheck: let
    launchRoots = lib.escapeShellArgs profile.launchRoots;
    trustedRootFlags = lib.concatMapStringsSep " " (root: "-trusted-root ${lib.escapeShellArg root}") profile.launchRoots;
  in ''
    if ${alreadySandboxedCheck}; then
      # Nested bwrap/sandbox-exec doesn't work; already inside a jail, so just run directly.
      exec "$target" "$@"
    fi

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

    wait_for_socket() {
      for _ in $(seq 1 50); do
        [ -S "$1" ] && return 0
        sleep 0.1
      done
      return 1
    }

    # Only the proxy ever talks to the real socket. Skipped when herdr isn't running.
    # Unset first: an inherited HERDR_SOCKET_PATH (e.g. from the herdr pane this was launched from)
    # must never survive un-exported past a skipped or failed proxy start, pointing at a real socket
    # this sandbox can't reach.
    unset HERDR_SOCKET_PATH
    real_herdr_socket="$HOME/.config/herdr/herdr.sock"
    if [ -S "$real_herdr_socket" ]; then
      herdr_proxy_log_dir="$HOME/.cache/agent-sandbox/herdr-proxy-logs"
      herdr_proxy_state_dir="$HOME/.cache/agent-sandbox/herdr-proxy-state"
      mkdir -p "$herdr_proxy_log_dir" "$herdr_proxy_state_dir"
      herdr_proxy_socket=${lib.escapeShellArg profile.herdrProxyRoot}/proxy-$$.sock
      herdr-agent-proxy \
        -listen "$herdr_proxy_socket" \
        -upstream "$real_herdr_socket" \
        ${trustedRootFlags} \
        -agent-kind ${lib.escapeShellArg agent} \
        -state-file "$herdr_proxy_state_dir/${agent}.json" \
        -active-workspace "''${HERDR_WORKSPACE_ID:-}" \
        >"$herdr_proxy_log_dir/${agent}-$$.log" 2>&1 &
      if wait_for_socket "$herdr_proxy_socket"; then
        export HERDR_SOCKET_PATH="$herdr_proxy_socket"
      else
        echo "${agent} sandbox: herdr-agent-proxy did not start within 5s (see $herdr_proxy_log_dir/${agent}-$$.log)" >&2
      fi
    fi

    # Resolve the host opener before the shim dir joins PATH, or the daemon would call its own shim.
    unset OPEN_URL_PROXY_SOCKET
    open_url_proxy_socket=""
    open_url_opener="$(type -P ${hostOpener} || true)"
    if [ -n "$open_url_opener" ]; then
      open_url_log_dir="$HOME/.cache/agent-sandbox/open-url-proxy-logs"
      mkdir -p "$open_url_log_dir"
      open_url_proxy_socket=${lib.escapeShellArg profile.herdrProxyRoot}/open-url-$$.sock
      open-url-proxy serve \
        -listen "$open_url_proxy_socket" \
        -opener "$open_url_opener" \
        >"$open_url_log_dir/${agent}-$$.log" 2>&1 &
      if wait_for_socket "$open_url_proxy_socket"; then
        export OPEN_URL_PROXY_SOCKET="$open_url_proxy_socket"
        export BROWSER=${openUrlProxy}/shims/xdg-open
        export PATH="${openUrlProxy}/shims:$PATH"
      else
        echo "${agent} sandbox: open-url-proxy did not start within 5s (see $open_url_log_dir/${agent}-$$.log)" >&2
        open_url_proxy_socket=""
      fi
    fi
  '';
in {
  inherit
    agentTools
    herdrAgentProxy
    mkLaunchSetup
    openUrlProxy
    ;
}

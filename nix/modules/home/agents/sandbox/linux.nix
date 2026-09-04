# Linux agent sandbox runner.
{
  lib,
  pkgs,
  policy,
  common,
}: let
  inherit (common) agentTools direnvRunner mkLaunchSetup;

  mkLinuxRunner = agent: profile: let
    readOnlyPaths = lib.escapeShellArgs profile.readOnlyPaths;
    socketPaths = lib.escapeShellArgs profile.socketPaths;
    writePaths = lib.escapeShellArgs profile.writePaths;
  in
    pkgs.writeShellApplication {
      name = "${agent}-outer-sandbox";
      runtimeInputs =
        agentTools
        ++ [
          pkgs.bubblewrap
          pkgs.nix
        ];
      text = ''
        target="''${1-}"
        if [ -z "$target" ]; then
          echo "${agent} sandbox: target executable is required" >&2
          exit 2
        fi
        shift

        ${mkLaunchSetup agent profile}

        home_parent="$(dirname "$HOME")"
        sandbox=(
          --die-with-parent
          --new-session
          --unshare-all
          --share-net
          --ro-bind /nix /nix
          --ro-bind /etc /etc
          --proc /proc
          --dev /dev
          --tmpfs /tmp
          --dir /tmp/agent-runtime
          --dir /run
          --dir /var
          --symlink /run /var/run
          --tmpfs /var/tmp
          --dir "$home_parent"
          --dir "$HOME"
          --dir "$HOME/.cache"
          --dir "$HOME/.config"
          --dir "$HOME/.local"
          --dir "$HOME/.local/share"
          --dir "$HOME/.local/state"
        )

        # systemd-resolved's stub-resolv.conf needs nss-resolve talking to a
        # Varlink socket under /run, which this sandbox's fresh /run doesn't
        # have -- nsswitch's "resolve [!UNAVAIL=return]" then fails DNS
        # entirely rather than falling back to plain DNS. Route to the
        # non-stub file (real nameservers, no socket needed) instead.
        if [ -e /run/systemd/resolve/resolv.conf ]; then
          sandbox+=(--ro-bind /run/systemd/resolve/resolv.conf /run/systemd/resolve/stub-resolv.conf)
        fi

        socket_paths=(${socketPaths})

        for path in ${readOnlyPaths}; do
          if [ -e "$path" ]; then
            sandbox+=(--ro-bind "$path" "$path")
          fi
        done

        # Expose only explicitly managed service sockets. The Docker daemon has
        # its own restricted filesystem view, independently of this boundary.
        for path in "''${socket_paths[@]}"; do
          if [ -S "$path" ]; then
            sandbox+=(--ro-bind "$path" "$path")
          fi
        done

        # Writable mounts come last so a narrow agent state directory can sit
        # below a read-only developer-runtime parent.
        for path in ${writePaths}; do
          if [ -e "$path" ]; then
            sandbox+=(--bind "$path" "$path")
          fi
        done

        exec bwrap "''${sandbox[@]}" \
          --chdir "$cwd_real" \
          --setenv HOME "$HOME" \
          --setenv TMPDIR /tmp \
          --setenv XDG_RUNTIME_DIR /tmp/agent-runtime \
          --setenv DOCKER_CONFIG ${lib.escapeShellArg profile.dockerConfigRoot} \
          --setenv NIX_REMOTE daemon \
          --setenv npm_config_cache ${lib.escapeShellArg policy.toolCachePaths.npm} \
          --setenv NUGET_PACKAGES ${lib.escapeShellArg policy.toolCachePaths.nugetPackages} \
          --setenv NUGET_HTTP_CACHE_PATH ${lib.escapeShellArg policy.toolCachePaths.nugetHttp} \
          --setenv NUGET_PLUGINS_CACHE_PATH ${lib.escapeShellArg policy.toolCachePaths.nugetPlugins} \
          ${
          if policy.sshAgentSocket != ""
          then "--setenv SSH_AUTH_SOCK ${lib.escapeShellArg policy.sshAgentSocket} \\"
          else "--unsetenv SSH_AUTH_SOCK \\"
        }
          -- ${direnvRunner}/bin/agent-direnv-runner "$cwd_real" "$target" "$@"
      '';
    };
in {
  mkRunner = mkLinuxRunner;
}

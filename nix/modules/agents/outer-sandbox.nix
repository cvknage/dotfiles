# Whole-process sandbox shared by Claude Code, Codex, and OpenCode. Native
# tools, plugins, MCP servers, and child processes all inherit this boundary.
{
  lib,
  pkgs,
  policy,
}: let
  escapeSeatbeltPath = path:
    builtins.replaceStrings ["\\" "\""] ["\\\\" "\\\""] path;

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
          --setenv SSH_AUTH_SOCK ${lib.escapeShellArg policy.sshAgentSocket} \
          -- ${direnvRunner}/bin/agent-direnv-runner "$cwd_real" "$target" "$@"
      '';
    };

  mkSeatbeltRules = operation: paths:
    lib.concatMapStringsSep "\n" (path: ''
      (allow ${operation} (subpath "${escapeSeatbeltPath path}"))
    '')
    paths;

  mkSeatbeltLiteralRules = operation: paths:
    lib.concatMapStringsSep "\n" (path: ''
      (allow ${operation} (literal "${escapeSeatbeltPath path}"))
    '')
    paths;

  mkMacRunner = agent: profile: let
    readRules = mkSeatbeltRules "file-read*" (profile.readOnlyPaths ++ profile.writePaths);
    socketReadRules = mkSeatbeltLiteralRules "file-read*" profile.socketPaths;
    socketNetworkRules = mkSeatbeltLiteralRules "network-outbound" profile.socketPaths;
    writeRules = mkSeatbeltRules "file-write*" profile.writePaths;
    seatbeltProfile = pkgs.writeText "${agent}-outer-sandbox.sb" ''
      (version 1)
      (deny default)
      (allow process*)
      (allow signal (target self))
      (allow sysctl-read)
      (allow mach-lookup)
      (allow network*)
      (allow file-read-metadata)
      (allow file-read* (literal "/dev/null") (literal "/dev/random") (literal "/dev/urandom") (literal "/dev/tty"))
      (allow file-write* (literal "/dev/null") (literal "/dev/tty"))
      (allow file-read* (subpath (param "TMPDIR")))
      (allow file-write* (subpath (param "TMPDIR")))
      ${readRules}
      ${socketReadRules}
      ${writeRules}
      (allow network-outbound (literal "${escapeSeatbeltPath policy.sshAgentSocket}"))
      ${socketNetworkRules}
    '';
  in
    pkgs.writeShellApplication {
      name = "${agent}-outer-sandbox";
      runtimeInputs = agentTools ++ [pkgs.nix];
      text = ''
        target="''${1-}"
        if [ -z "$target" ]; then
          echo "${agent} sandbox: target executable is required" >&2
          exit 2
        fi
        shift

        ${mkLaunchSetup agent profile}

        export DOCKER_CONFIG=${lib.escapeShellArg profile.dockerConfigRoot}
        export NIX_REMOTE=daemon
        export npm_config_cache=${lib.escapeShellArg policy.toolCachePaths.npm}
        export NUGET_PACKAGES=${lib.escapeShellArg policy.toolCachePaths.nugetPackages}
        export NUGET_HTTP_CACHE_PATH=${lib.escapeShellArg policy.toolCachePaths.nugetHttp}
        export NUGET_PLUGINS_CACHE_PATH=${lib.escapeShellArg policy.toolCachePaths.nugetPlugins}
        export SSH_AUTH_SOCK=${lib.escapeShellArg policy.sshAgentSocket}
        exec /usr/bin/sandbox-exec \
          -D "TMPDIR=''${TMPDIR:-/tmp}" \
          -f ${seatbeltProfile} \
          ${direnvRunner}/bin/agent-direnv-runner "$cwd_real" "$target" "$@"
      '';
    };

  mkRunner = agent: profile:
    if pkgs.stdenv.hostPlatform.isDarwin
    then mkMacRunner agent profile
    else mkLinuxRunner agent profile;

  runners = lib.mapAttrs mkRunner policy.outerSandboxProfiles;

  wrapPackage = {
    agent,
    package,
    executable,
  }: let
    runner = runners.${agent};
  in
    pkgs.symlinkJoin {
      name = "${agent}-outer-sandboxed-${lib.getName package}";
      version = lib.getVersion package;
      paths = [package];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        rm -f "$out/bin/${executable}"
        makeWrapper ${runner}/bin/${agent}-outer-sandbox "$out/bin/${executable}" \
          --add-flags ${lib.escapeShellArg "${package}/bin/${executable}"}
      '';
    };
in {
  inherit wrapPackage;
}

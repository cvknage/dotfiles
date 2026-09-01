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
          ${
          if policy.sshAgentSocket != ""
          then "--setenv SSH_AUTH_SOCK ${lib.escapeShellArg policy.sshAgentSocket} \\"
          else "--unsetenv SSH_AUTH_SOCK \\"
        }
          -- ${direnvRunner}/bin/agent-direnv-runner "$cwd_real" "$target" "$@"
      '';
    };

  # Both on-disk spellings of a home path: the sandbox resolves the
  # /System/Volumes/Data firmlink before matching, so each rule needs both.
  homeSpellings = path:
    if lib.hasPrefix policy.homeDirectory path
    then [
      path
      (builtins.replaceStrings ["/Users/"] ["/System/Volumes/Data/Users/"] path)
    ]
    else [path];

  # Deny-by-default Seatbelt profile. macOS pitfalls: an undefined `(param ...)`
  # breaks compilation, and denied IPC/tty/file-map-executable ops abort the
  # process silently (SIGABRT), so the system baseline must stay complete.
  # Last-match-wins: the broad home deny followed by narrower allows yields
  # allowlist semantics for $HOME.
  mkSeatbeltAllowRule = operation: path:
    lib.concatMapStrings (spelling: ''
      (allow ${operation} (subpath "${escapeSeatbeltPath spelling}"))
    '')
    (homeSpellings path);

  mkSeatbeltLiteralAllowRule = operation: path:
    lib.concatMapStrings (spelling: ''
      (allow ${operation} (literal "${escapeSeatbeltPath spelling}"))
    '')
    (homeSpellings path);

  mkMacRunner = agent: profile: let
    # Each agent may read only its own credentials; others stay denied.
    ownCredentialSuffix = builtins.getAttr agent {
      claude = "/.claude/.credentials.json";
      codex = "/.codex/auth.json";
      opencode = "/.local/share/opencode/auth.json";
    };
    ownCredentialPath =
      lib.findFirst (path: lib.hasSuffix ownCredentialSuffix path)
      null
      policy.deniedPaths;

    homeDenyRules =
      lib.concatMapStrings (spelling: ''
        (deny file-read* file-write* (subpath "${escapeSeatbeltPath spelling}"))
      '')
      (homeSpellings policy.homeDirectory);

    readAllows = lib.concatMapStrings (mkSeatbeltAllowRule "file-read*") (
      profile.readOnlyPaths
      ++ lib.optional (ownCredentialPath != null) ownCredentialPath
    );
    socketReadAllows = lib.concatMapStrings (mkSeatbeltLiteralAllowRule "file-read*") profile.socketPaths;
    socketNetworkAllows = lib.concatMapStrings (mkSeatbeltLiteralAllowRule "network-outbound") profile.socketPaths;
    # Writable roots need read too: O_RDWR opens and readdir are reads.
    # Matches bwrap --bind, which grants both.
    writeAllows = lib.concatMapStrings (mkSeatbeltAllowRule "file-read* file-write*") profile.writePaths;
    seatbeltProfile = pkgs.writeText "${agent}-outer-sandbox.sb" ''
      (version 1)
      ; System runtime baseline every process needs.
      (deny default)
      (allow process*)
      (allow signal (target self))
      (allow process-info* (target same-sandbox))
      (allow sysctl-read)
      (allow sysctl-write (sysctl-name "kern.grade_cputype"))
      (allow mach-lookup)
      (allow network*)
      ; Keychain stays reachable (HTTPS-based auth); AppleEvents do not.
      (deny appleevent-send)
      (allow system-socket (socket-domain AF_UNIX))
      (allow ipc-posix-sem)
      (allow ipc-posix-shm*
        (ipc-posix-name "apple.shm.notification_center")
        (ipc-posix-name-prefix "apple.cfprefs."))
      (allow user-preference-read)
      (allow iokit-open (iokit-registry-entry-class "RootDomainUserClient"))
      (allow system-mac-syscall (mac-policy-name "vnguard"))
      (allow system-mac-syscall
        (require-all (mac-policy-name "Sandbox") (mac-syscall-number 67)))
      (allow system-fsctl (fsctl-command FSIOC_CAS_BSDFLAGS))
      (allow file-read-metadata)
      (allow file-map-executable
        (subpath "/Library/Apple")
        (subpath "/nix")
        (subpath "/opt/homebrew")
        (subpath "/System")
        (subpath "/usr")
        (subpath "/bin")
        (subpath "/sbin"))
      (allow file-read* file-test-existence
        (literal "/")
        (literal "/etc/localtime")
        (literal "/etc/master.passwd")
        (literal "/etc/passwd")
        (literal "/etc/protocols")
        (literal "/etc/services")
        (literal "/private/etc/localtime")
        (literal "/private/etc/master.passwd")
        (literal "/private/etc/passwd")
        (literal "/private/etc/protocols")
        (literal "/private/etc/services")
        (literal "/System/Library/CoreServices")
        (literal "/System/Library/CoreServices/SystemVersion.plist"))
      (allow file-read* (subpath "/nix"))
      (allow file-read* file-test-existence
        (subpath "/System/Volumes/Data/private/var/db")
        (subpath "/private/var/db"))
      (allow file-read-metadata (subpath "/System/Volumes/Data/private/var"))
      (allow file-read-metadata (subpath "/private/var"))
      (allow file-read* file-write*
        (literal "/dev/null")
        (literal "/dev/random")
        (literal "/dev/urandom")
        (literal "/dev/tty"))
      (allow file-read* file-test-existence file-write-data
        (literal "/dev/autofs_nowait")
        (literal "/dev/zero"))
      (allow file-read-data file-test-existence file-write-data (subpath "/dev/fd"))
      (allow file-read* (regex "^/dev/fd/(0|1|2)$"))
      (allow file-write* (regex "^/dev/fd/(1|2)$"))
      (allow file-read-metadata (regex "^/dev/"))
      (allow pseudo-tty)
      (allow file-read* file-write* (literal "/dev/ptmx"))
      (allow file-read* file-write* (regex "^/dev/ttys[0-9]+$"))
      (allow file-ioctl (regex "^/dev/ttys[0-9]+$"))
      (allow file-read* file-write* file-ioctl (literal "/dev/dtracehelper"))
      (allow network-outbound (literal "/private/var/run/syslog"))
      ; Scratch space. TMPDIR resolves into /var/folders and needs its -D
      ; definition, otherwise the (param ...) breaks compilation.
      (allow file-read* file-test-existence file-write* (subpath "/tmp"))
      (allow file-read* file-write* (subpath "/private/tmp"))
      (allow file-read* file-write* (subpath "/var/tmp"))
      (allow file-read* file-write* (subpath "/private/var/tmp"))
      (allow file-read* file-test-existence file-write* (subpath (param "TMPDIR")))
      (allow file-read-metadata (subpath "/var/folders"))
      (allow file-read-metadata (subpath "/private/var/folders"))
      (allow file-read-metadata (subpath "/System/Volumes/Data/private/var/folders"))
      (allow file-read* file-test-existence file-write* (subpath "/var/folders"))
      (allow file-read* file-test-existence file-write* (subpath "/private/var/folders"))
      (allow file-read* file-test-existence file-write* (subpath "/System/Volumes/Data/private/var/folders"))
      ; Deny all of $HOME, then re-open the managed roots.
      ${homeDenyRules}
      ${readAllows}
      ${socketReadAllows}
      ${socketNetworkAllows}
      ${writeAllows}
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
        ${
          if policy.sshAgentSocket != ""
          then "export SSH_AUTH_SOCK=${lib.escapeShellArg policy.sshAgentSocket}"
          else "unset SSH_AUTH_SOCK"
        }

        # setrlimit is EPERM inside the sandbox; raise the fd limit here so
        # the target never needs it.
        ulimit -n 2147483646 2>/dev/null || true

        sandbox_command=(
          /usr/bin/sandbox-exec
          -D "TMPDIR=''${TMPDIR:-/tmp}"
          -f ${seatbeltProfile}
        )

        # Fail fast if the profile cannot compile or apply.
        preflight_output="$("''${sandbox_command[@]}" /usr/bin/true 2>&1)" && preflight_status=0 || preflight_status=$?
        if [ "$preflight_status" -ne 0 ]; then
          if [ "''${AGENT_SANDBOX_DEBUG:-0}" = 1 ]; then
            echo "${agent} sandbox: profile preflight failed with status $preflight_status" >&2
            printf '%s\n' "$preflight_output" >&2
          else
            echo "${agent} sandbox: profile preflight failed; set AGENT_SANDBOX_DEBUG=1 for details" >&2
          fi
          exit "$preflight_status"
        fi

        exec "''${sandbox_command[@]}" \
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

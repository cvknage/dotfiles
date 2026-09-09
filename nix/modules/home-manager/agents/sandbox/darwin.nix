# macOS agent sandbox runner using Seatbelt.
{
  lib,
  pkgs,
  policy,
  common,
}: let
  inherit (common) agentTools direnvRunner mkLaunchSetup;

  escapeSeatbeltPath = path:
    builtins.replaceStrings ["\\" "\""] ["\\\\" "\\\""] path;

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
in {
  mkRunner = mkMacRunner;
}

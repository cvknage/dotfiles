# macOS agent sandbox runner using Seatbelt.
{
  lib,
  pkgs,
  policy,
  common,
}: let
  inherit (common) agentTools direnvRunner mkLaunchSetup;

  mkMacRunner = agent: profile: let
    # Filters quote their paths, so escape whatever would end the string early.
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

    # A rule per spelling of the path, in the profile's two filter shapes: subpath for a tree,
    # literal for a single file.
    subpathAllow = operation: path:
      lib.concatMapStrings (spelling: ''
        (allow ${operation} (subpath "${escapeSeatbeltPath spelling}"))
      '')
      (homeSpellings path);

    literalAllow = operation: path:
      lib.concatMapStrings (spelling: ''
        (allow ${operation} (literal "${escapeSeatbeltPath spelling}"))
      '')
      (homeSpellings path);

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

    # $HOME, denied outright and then re-opened by the two allows below.
    homeDenyRules =
      lib.concatMapStrings (spelling: ''
        (deny file-read* file-write* (subpath "${escapeSeatbeltPath spelling}"))
      '')
      (homeSpellings policy.homeDirectory);

    homeReadAllows = lib.concatMapStrings (subpathAllow "file-read*") (
      profile.readOnlyPaths
      ++ lib.optional (ownCredentialPath != null) ownCredentialPath
    );

    # Writable roots need read too: O_RDWR opens and readdir are reads.
    # Matches bwrap --bind, which grants both.
    homeWriteAllows = lib.concatMapStrings (subpathAllow "file-read* file-write*") profile.writePaths;

    # socketPaths entries are "host:sandbox" pairs; Seatbelt has no mount namespace, so only the host path matters.
    socketHostPaths = map (entry: lib.head (lib.splitString ":" entry)) profile.socketPaths;
    # Reaching a unix socket takes both: read to resolve the node, network-outbound to connect.
    socketReadAllows = lib.concatMapStrings (literalAllow "file-read*") socketHostPaths;
    socketNetworkAllows = lib.concatMapStrings (literalAllow "network-outbound") socketHostPaths;

    # The sops-nix runtime store lives under the scratch-space allows above, so it is denied
    # here and last: last match wins, and each firmlink spelling is denied to override the
    # /var/folders allow carrying it. file-read-metadata and file-test-existence are named
    # separately because `file-read*` does NOT cover them, and the global metadata allow
    # above still reaches this tree without them.
    sopsSecretsDenies = lib.concatMapStrings (
      param: ''
        (deny file-read* file-read-metadata file-test-existence file-write* (subpath (param "${param}")))
      ''
    ) ["SOPS_SECRETS" "SOPS_SECRETS_PRIVATE" "SOPS_SECRETS_DATA"];

    # Deny-by-default Seatbelt profile. macOS pitfalls: an undefined `(param ...)`
    # breaks compilation, and denied IPC/tty/file-map-executable ops abort the
    # process silently (SIGABRT), so the system baseline must stay complete.
    # Last-match-wins: the broad home deny followed by narrower allows yields
    # allowlist semantics for $HOME.
    seatbeltProfile = pkgs.writeText "${agent}-outer-sandbox.sb" ''
      (version 1)

      ; Foundation: deny everything, then re-open what any process needs to run.
      (deny default)
      (allow process*)
      (allow signal (target self))
      (allow signal (target same-sandbox))
      (allow process-info* (target same-sandbox))
      (allow sysctl-read)
      (allow sysctl-write (sysctl-name "kern.grade_cputype"))
      (allow mach-lookup)

      ; Network is open; AppleEvents are not, and the Keychain stays reachable for HTTPS auth.
      (allow network*)
      (deny appleevent-send)

      ; IPC and system services.
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

      ; Filesystem: metadata everywhere (traversal needs it), then system files and
      ; executables the runtime needs.
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

      ; Devices, ttys and the syslog socket.
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
      ${homeReadAllows}
      ${homeWriteAllows}
      ${socketReadAllows}
      ${socketNetworkAllows}
      ${sopsSecretsDenies}
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
        export GIT_SSH_COMMAND="ssh -o BatchMode=yes"
        ${
          if policy.sshAgentSocket != ""
          then "export SSH_AUTH_SOCK=${lib.escapeShellArg policy.sshAgentSocket}"
          else "unset SSH_AUTH_SOCK"
        }

        # setrlimit is EPERM inside the sandbox; raise the fd limit here so
        # the target never needs it.
        ulimit -n 2147483646 2>/dev/null || true

        # sops-nix resolves its secrets mount point as "<runtime dir>/secrets.d", where the
        # runtime dir is `getconf DARWIN_USER_TEMP_DIR` on darwin. Resolve it the same way so
        # the denylist tracks sops instead of guessing from $TMPDIR, which may be unset; the
        # `|| true` keeps the guard below reachable under errexit.
        sops_runtime_dir="$(getconf DARWIN_USER_TEMP_DIR || true)"
        sops_runtime_dir="''${sops_runtime_dir%/}"
        sops_secrets="$sops_runtime_dir/secrets.d"
        if [ "$sops_secrets" = "/secrets.d" ]; then
          echo "${agent} sandbox: cannot resolve DARWIN_USER_TEMP_DIR for the sops denylist" >&2
          exit 1
        fi

        sandbox_command=(
          /usr/bin/sandbox-exec
          -D "TMPDIR=''${TMPDIR:-/tmp}"
          -D "SOPS_SECRETS=$sops_secrets"
          -D "SOPS_SECRETS_PRIVATE=/private$sops_secrets"
          -D "SOPS_SECRETS_DATA=/System/Volumes/Data/private$sops_secrets"
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

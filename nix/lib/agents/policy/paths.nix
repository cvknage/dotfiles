# One source of truth for Claude Code, Codex, and OpenCode.
{
  lib,
  homeDirectory,
  xdgConfigHome,
  isDarwin,
  # Directory the git identity publishes its files to, or null if none enabled.
  gitIdentityDirectory ? null,
}: let
  inHome = paths: map (path: "${homeDirectory}/${path}") paths;

  # Workspaces are shared by every agent and deliberately writable.
  workspaceRoots = [
    "${homeDirectory}/.dotfiles"
    "${homeDirectory}/${
      if isDarwin
      then "Code"
      else "code"
    }"
  ];

  # Keep each agent's paths together so its launch, runtime, and permission
  # roots cannot drift apart.
  agentPaths = {
    claude = rec {
      configRoot = "${homeDirectory}/.claude";
      mutableSettingsPath = "${homeDirectory}/.local/state/claude/settings.json";
      # Claude names its scratch root after the running uid, which no tier resolves at eval
      # time (see runtimeCredentialDirs), so this is a rule pattern, not a bindable path.
      scratchRoots = lib.optionals (!isDarwin) ["/tmp/claude-*"];
      trustedRoots = workspaceRoots ++ [configRoot];
      runtimeRoots = [
        configRoot
        "${homeDirectory}/.local/state/claude"
        "${homeDirectory}/.cache/claude-cli-nodejs"
        mcpAuthRoot
      ];
      runtimeFiles = [];
    };
    codex = rec {
      configRoot = "${homeDirectory}/.codex";
      mutableConfigPath = "${homeDirectory}/.local/state/codex/config.toml";
      trustedRoots = workspaceRoots ++ [configRoot];
      runtimeRoots = [
        configRoot
        "${homeDirectory}/.local/state/codex"
        mcpAuthRoot
      ];
      runtimeFiles = [];
    };
    opencode = rec {
      configRoot = "${xdgConfigHome}/opencode";
      authFile = "${homeDirectory}/.local/share/opencode/auth.json";
      trustedRoots = workspaceRoots ++ [configRoot];
      runtimeRoots = [
        configRoot
        "${homeDirectory}/.cache/opencode"
        "${homeDirectory}/.local/share/opencode"
        "${homeDirectory}/.local/state/opencode"
        mcpAuthRoot
      ];
      runtimeFiles = [];
    };
  };

  # Remote MCP OAuth sessions are shared by the configured agents. Keep this
  # separate from their own config roots so the credential scope stays explicit.
  mcpAuthRoot = "${homeDirectory}/.mcp-auth";

  # Shared development state exposed to every agent.
  kubernetesStateRoots = inHome [
    ".azure"
    ".kube"
    ".minikube"
  ];

  # Only exposed when the identity is enabled; elsewhere the socket does not
  # exist, so agents get no agent at all.
  sshAgentSocket =
    if gitIdentityDirectory != null
    then "${gitIdentityDirectory}/ssh-agent.sock"
    else "";
  # The sandbox never talks to the real docker.sock; docker-agent-proxy enforces deniedPaths instead.
  dockerProxySocketPath = "/run/docker-agent-proxy.sock";
  serviceSocketMappings =
    [
      {
        host = "/nix/var/nix/daemon-socket/socket";
        sandbox = "/nix/var/nix/daemon-socket/socket";
      }
    ]
    ++ lib.optionals (!isDarwin) [
      {
        host = dockerProxySocketPath;
        sandbox = "/run/docker.sock";
      }
    ];

  toolCachePaths = {
    npm = "${homeDirectory}/.npm";
    nugetPackages = "${homeDirectory}/.nuget/packages";
    nugetHttp = "${homeDirectory}/.local/share/NuGet/v3-cache";
    nugetPlugins = "${homeDirectory}/.local/share/NuGet/plugins-cache";
  };

  # Immutable runtimes and user-level tool configuration. The rest of the home
  # directory is absent from the OS sandbox.
  sharedReadOnlyPaths = inHome [
    ".agents/skills"
    ".bashrc"
    ".cargo"
    ".config/direnv"
    ".config/git"
    # Always exposed, even where the identity is disabled: git includes includes.inc
    # unconditionally, and concealment turns the missing file into EPERM, which libgit2
    # treats as a fatal error instead of skipping the include.
    ".config/git-identity"
    ".config/nix"
    ".config/nvim"
    ".gitconfig"
    ".local/share/CSharpier"
    ".local/share/EasyDotnet"
    ".local/share/NuGet"
    ".local/share/Nuget"
    ".local/share/dotnet"
    ".local/share/nix"
    ".local/share/pnpm"
    ".local/share/uv"
    ".local/state/nix"
    ".nix-defexpr"
    ".nix-profile"
    ".nuget"
    ".profile"
    ".rustup"
    ".ssh/known_hosts" # public keys only, fixes sandboxed git-over-ssh having no known_hosts
    ".terminfo"
    ".zprofile"
    ".zshenv"
    ".zshrc"
    "go"
  ];

  # Development caches are intentionally writable. Keeping the list explicit
  # avoids exposing unrelated browser and desktop application state.
  sharedWritablePaths =
    builtins.attrValues toolCachePaths
    ++ inHome [
      ".cache/biome"
      ".cache/bun"
      ".cache/code-graph"
      ".cache/deno"
      ".cache/direnv"
      ".cache/nix"
      ".cache/node"
      ".cache/node-gyp"
      ".cache/nvim"
      ".cache/pip"
      ".cache/pnpm"
      ".cache/typescript"
      ".cache/uv"
      ".cache/yarn"
      ".dotnet"
      ".local/share/direnv/allow"
      ".local/share/nvim"
      ".local/share/pnpm/store"
      ".local/state/agent-memory"
    ];

  systemReadOnlyPaths =
    [
      "/bin"
      "/etc"
      "/nix"
      "/sbin"
      "/usr"
    ]
    ++ lib.optionals isDarwin [
      "/Applications/Xcode.app"
      "/Library/Application Support/ClaudeCode"
      "/Library/Application Support/opencode"
      "/Library/Developer"
      "/System"
      "/private/etc"
    ]
    ++ lib.optionals (!isDarwin) [
      # The system profile carries tools that are not in the user profile,
      # including the Docker client enabled by the NixOS Docker module.
      "/run/current-system"

      # Symlinks to /usr/lib{,64} on FHS distros. Without these, no host
      # binary's dynamic linker can be found, and exec fails with a
      # misleading "No such file or directory" instead of a linker error.
      "/lib"
      "/lib64"
    ];

  # Translate the path model above into the common whole-process sandbox shape.
  mkOuterProfile = {
    configRoot,
    trustedRoots,
    runtimeRoots,
    runtimeFiles,
    ...
  }: let
    dockerConfigRoot = "${configRoot}/.sandbox/docker";
  in {
    inherit dockerConfigRoot;
    launchRoots = trustedRoots;
    readOnlyPaths =
      sharedReadOnlyPaths
      ++ systemReadOnlyPaths;
    socketPaths = map (m: "${m.host}:${m.sandbox}") serviceSocketMappings;
    writePaths = workspaceRoots ++ sharedWritablePaths ++ runtimeRoots ++ runtimeFiles ++ kubernetesStateRoots;
    ensureDirectories = sharedWritablePaths ++ runtimeRoots ++ kubernetesStateRoots ++ [dockerConfigRoot];
    ensureFiles = runtimeFiles;
  };

  outerSandboxProfiles = lib.mapAttrs (_: paths: mkOuterProfile paths) agentPaths;

  # Private host data excluded from both the agent and Docker views.
  credentialPaths =
    inHome [
      ".aws"
      ".bash_history"
      ".claude/.credentials.json"
      ".codex/auth.json"
      ".config/git/credentials"
      ".config/sops"
      ".config/sops-nix"
      ".docker/config.json"
      ".git-credentials"
      ".gnupg"
      ".local/share/fish/fish_history"
      ".local/share/opencode/auth.json"
      ".netrc"
      ".npmrc"
      ".ssh"
      ".zsh_history"
    ]
    ++ lib.optionals (!isDarwin) [
      "/run/keys"
      "/run/secrets"
    ];

  # Private subtrees of the user's XDG_RUNTIME_DIR, /run/user/<uid>. The uid is deliberately
  # absent: NixOS leaves users.users.<user>.uid null (activation allocates it), which makes
  # home.uid null there too, and the System Manager and standalone Home Manager hosts declare no
  # user at all -- so no tier can resolve it while the policy evaluates. Each consumer spells it
  # the way it can: the docker-agent-proxy units resolve `id -u` when the unit starts, and the
  # agent rule files below glob it. Never deny /run/user itself; the session's sockets live there.
  runtimeCredentialDirs = ["gnupg" "secrets.d"];

  personalPaths = inHome (
    [
      "Desktop"
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
    ]
    ++ (
      if isDarwin
      then [
        "Applications"
        "Library"
        "Movies"
      ]
      else [
        "Public"
        "Templates"
        "Videos"
        ".mozilla"
        ".thunderbird"
      ]
    )
  );
  deniedPaths = credentialPaths ++ personalPaths;

  # deniedPaths for consumers that match by glob rather than by literal prefix, so they can
  # cover every /run/user/<uid> without knowing which one is live.
  deniedPathPatterns =
    deniedPaths
    ++ lib.optionals (!isDarwin) (map (dir: "/run/user/*/${dir}") runtimeCredentialDirs);

  # Paths denied to CONTAINERS only, via docker-agent-proxy -- deliberately NOT in deniedPaths,
  # which doubles as the in-sandbox agent denylist: the agents themselves reach gh's token, the
  # MCP OAuth store, and ollama, so those denies must not apply to the agent, only to containers.
  # The two docker sockets are denied so no container can bind-mount them; only the proxy reads
  # this list, so the socket entries are inert in the OS sandbox.
  dockerDeniedPaths =
    deniedPaths
    ++ inHome [
      ".config/gh"
      ".ollama"
    ]
    ++ [mcpAuthRoot]
    ++ lib.optionals (!isDarwin) [
      "/run/docker.sock"
      dockerProxySocketPath
    ];

  # Nix-owned global settings cannot be edited by the agents. Project settings
  # require approval so intentional team configuration remains possible.
  claudeGlobalSettingsPaths = [
    "${agentPaths.claude.configRoot}/settings.json"
    "${agentPaths.claude.configRoot}/settings.local.json"
    agentPaths.claude.mutableSettingsPath
  ];
  claudeProjectSettingsPaths =
    lib.concatMap (root: [
      "${root}/.claude/settings.json"
      "${root}/.claude/settings.local.json"
      "${root}/**/.claude/settings.json"
      "${root}/**/.claude/settings.local.json"
    ])
    workspaceRoots;
  opencodeGlobalSettingsPaths = [
    "${agentPaths.opencode.configRoot}/opencode.json"
    "${agentPaths.opencode.configRoot}/opencode.jsonc"
  ];
  opencodeProjectSettingsPaths =
    lib.concatMap (root: [
      "${root}/opencode.json"
      "${root}/opencode.jsonc"
      "${root}/**/opencode.json"
      "${root}/**/opencode.jsonc"
    ])
    workspaceRoots;
in {
  inherit
    agentPaths
    claudeGlobalSettingsPaths
    claudeProjectSettingsPaths
    deniedPathPatterns
    deniedPaths
    dockerDeniedPaths
    dockerProxySocketPath
    homeDirectory
    opencodeGlobalSettingsPaths
    opencodeProjectSettingsPaths
    outerSandboxProfiles
    runtimeCredentialDirs
    sshAgentSocket
    toolCachePaths
    workspaceRoots
    ;
}

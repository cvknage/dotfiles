# One source of truth for Claude Code, Codex, and OpenCode.
{
  lib,
  homeDirectory,
  xdgConfigHome,
  isDarwin,
  isWork ? false,
  uid ? 1000,
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
      scratchRoots = lib.optionals (!isDarwin) ["/tmp/claude-${toString uid}"];
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
      trustedRoots = workspaceRoots ++ [configRoot];
      runtimeRoots = [
        configRoot
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

  gitIdentityDirectory = "${xdgConfigHome}/git-identity";
  # Only the work profile runs the signing relay; elsewhere the socket does
  # not exist, so agents get no agent at all.
  sshAgentSocket =
    if isWork
    then "${gitIdentityDirectory}/ssh-agent.sock"
    else "";
  serviceSockets =
    ["/nix/var/nix/daemon-socket/socket"]
    ++ lib.optionals (!isDarwin) ["/run/docker.sock"];

  toolCachePaths = {
    npm = "${homeDirectory}/.npm";
    nugetPackages = "${homeDirectory}/.nuget/packages";
    nugetHttp = "${homeDirectory}/.local/share/NuGet/v3-cache";
    nugetPlugins = "${homeDirectory}/.local/share/NuGet/plugins-cache";
  };

  # Immutable runtimes and user-level tool configuration. The rest of the home
  # directory is absent from the OS sandbox.
  sharedReadOnlyPaths = inHome [
    ".bashrc"
    ".cargo"
    ".config/direnv"
    ".config/git"
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
      ++ systemReadOnlyPaths
      ++ lib.optionals isWork [gitIdentityDirectory];
    socketPaths = serviceSockets;
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
      "/run/user/${toString uid}/gnupg"
      "/run/user/${toString uid}/secrets.d"
    ];

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
    deniedPaths
    homeDirectory
    opencodeGlobalSettingsPaths
    opencodeProjectSettingsPaths
    outerSandboxProfiles
    sshAgentSocket
    toolCachePaths
    workspaceRoots
    ;
}

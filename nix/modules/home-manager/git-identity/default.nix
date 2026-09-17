# A dedicated single-key SSH identity for git auth and signing.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.preferences.gitIdentity;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  identityDirectory = "${config.xdg.configHome}/git-identity";
  identitySocket = "${identityDirectory}/ssh-agent.sock";
  # The published copy, not the sops path: git reads it as user.signingkey, including from
  # inside the sandbox, and the sops render location is deliberately denied there.
  publicKeyPath = "${identityDirectory}/identity.pub";

  # Every input publishIdentity needs rendered before it can do anything. The private key
  # belongs here with the templates -- publishing a symlink to a key that never rendered is
  # exactly the silent failure this service exists to prevent.
  publishInputs = [
    config.sops.templates."git-identity.inc".path
    config.sops.templates."git-allowed-signers".path
    config.sops.templates."git-public-key".path
    cfg.keyPath
  ];

  publishIdentity = pkgs.writeShellApplication {
    name = "publish-git-identity";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      required=(${lib.escapeShellArgs publishInputs})

      for _attempt in $(seq 1 30); do
        ready=1
        for input in "''${required[@]}"; do
          [ -r "$input" ] || ready=0
        done
        if [ "$ready" = 1 ]; then
          break
        fi
        sleep 1
      done

      # Fail loudly rather than publishing a half-built identity that only breaks later, at
      # signing time, with nothing pointing back here.
      for input in "''${required[@]}"; do
        if [ ! -r "$input" ]; then
          echo "publish-git-identity: $input is still unreadable after 30s" >&2
          exit 1
        fi
      done

      publish() {
        rm -f "$2"
        install -D -m 0444 "$1" "$2"
      }

      publish ${config.sops.templates."git-identity.inc".path} ${identityDirectory}/git-identity.inc
      publish ${config.sops.templates."git-allowed-signers".path} ${identityDirectory}/allowed-signers
      publish ${config.sops.templates."git-public-key".path} ${identityDirectory}/identity.pub

      # gitui signs via libgit2, which wants the private key next to user.signingkey
      # (gitui-org/gitui#2184). A symlink keeps the sops-rendered key out of the published
      # copies; its target resolves into the sops secret store, which both sandboxes deny --
      # linux by never mounting it, darwin by the explicit deny in the Seatbelt profile.
      ln -sfn ${lib.escapeShellArg cfg.keyPath} ${identityDirectory}/identity
    '';
  };

  # Dedicated, holding only this identity's key: reusing the session's agent, or relaying
  # into it, would expose every unrelated key it holds to anything using this socket.
  identityAgent = pkgs.writeShellApplication {
    name = "git-identity-agent";
    runtimeInputs = [pkgs.coreutils pkgs.openssh];
    text = ''
      mkdir -p ${identityDirectory}
      rm -f ${identitySocket}
      exec ssh-agent -D -a ${identitySocket}
    '';
  };

  addIdentityKey = pkgs.writeShellApplication {
    name = "add-git-identity-key";
    runtimeInputs = [pkgs.coreutils pkgs.openssh];
    text = ''
      # The private key is sops-rendered outside the sandbox's reach, so wait for it too --
      # the agent starting first is not enough for ssh-add to succeed.
      for _attempt in $(seq 1 30); do
        [ -S ${identitySocket} ] && [ -r ${lib.escapeShellArg cfg.keyPath} ] && break
        sleep 1
      done

      SSH_AUTH_SOCK=${identitySocket} ssh-add ${lib.escapeShellArg cfg.keyPath}
    '';
  };

  # user.signingkey is a public key file, and ssh-keygen can only reach the private half
  # through an agent -- so point it at the identity's, whatever SSH_AUTH_SOCK the caller has.
  identitySigningProgram = pkgs.writeShellApplication {
    name = "git-identity-ssh-keygen";
    runtimeInputs = [pkgs.openssh];
    text = ''
      export SSH_AUTH_SOCK=${lib.escapeShellArg identitySocket}
      exec ssh-keygen "$@"
    '';
  };

  # The three remote URL forms CLI git's own hasconfig include needs to match.
  hasconfigUrls = [
    "git@${cfg.sshHost}:${cfg.remoteMatch}/**"
    "ssh://git@${cfg.sshHost}/${cfg.remoteMatch}/**"
    "https://${cfg.sshHost}/${cfg.remoteMatch}/**"
  ];
in {
  options.preferences.gitIdentity = {
    enable = lib.mkEnableOption "a dedicated single-key SSH identity for git auth, signing, and gitui";

    email = lib.mkOption {
      type = lib.types.str;
      description = "git user.email for repos matching remoteMatch on sshHost.";
    };

    publicKey = lib.mkOption {
      type = lib.types.str;
      description = "The identity key's public key for allowed-signers. Only meaningful inside a sops.templates block: the value is a placeholder token, not the key text.";
    };

    keyPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to the identity's private key file.";
    };

    remoteMatch = lib.mkOption {
      type = lib.types.str;
      description = "Path segment (e.g. a GitHub org) matched against remote URLs on sshHost to decide when this identity applies.";
    };

    sshHost = lib.mkOption {
      type = lib.types.str;
      default = "github.com";
      description = "SSH host this identity authenticates to.";
    };

    directory = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Directory the identity publishes its include and allowed-signers files to.";
    };

    socket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Path to the identity's dedicated ssh-agent socket.";
    };
  };

  config = lib.mkMerge [
    {
      # Read-only derived values, so consumers need not re-derive the identity's layout.
      # `readOnly` means at most one definition -- never give these a `default`, which counts
      # as a second.
      preferences.gitIdentity = {
        directory = identityDirectory;
        socket = identitySocket;
      };
    }

    (lib.mkIf cfg.enable (lib.mkMerge [
      {
        # Applies to every sshHost connection, unlike the github-secrets identity, so it needs
        # no Host alias. IdentityFile plus IdentitiesOnly pins the key instead of leaving the
        # choice to the session's agent.
        programs.ssh.settings.${cfg.sshHost} = {
          HostName = cfg.sshHost;
          User = "git";
          IdentityFile = cfg.keyPath;
          IdentitiesOnly = "yes";
        };

        # Non-secret, so this renders immediately instead of waiting on sops-nix; a missing include is a silent no-op.
        xdg.configFile."git-identity/includes.inc".text =
          lib.concatMapStrings (url: ''
            [includeIf "hasconfig:remote.*.url:${url}"]
            	path = ${identityDirectory}/git-identity.inc
          '')
          hasconfigUrls;

        sops.templates = {
          "git-public-key".content = ''
            ${cfg.publicKey}
          '';

          "git-allowed-signers".content = ''
            ${cfg.email} namespaces="git" ${cfg.publicKey}
          '';

          "git-identity.inc".content = ''
            [user]
              email = ${cfg.email}
              signingkey = ${publicKeyPath}
            [gpg]
              format = ssh
            [gpg "ssh"]
              allowedSignersFile = ${identityDirectory}/allowed-signers
              program = ${identitySigningProgram}/bin/git-identity-ssh-keygen
            [commit]
              gpgsign = true
            [tag]
              gpgsign = true
          '';
        };
      }

      # Linux sops-nix renders via a user service, so publishing runs after it, not a racing Home Manager activation entry.
      (lib.mkIf (!isDarwin) {
        systemd.user.services = {
          sops-nix.Service.ExecStartPost = ["${publishIdentity}/bin/publish-git-identity"];

          git-identity-agent = {
            Unit.Description = "Dedicated single-key SSH agent for Git auth and signing";
            # Order the agent after secrets render so ssh-add is not racing sops; the retry
            # in addIdentityKey stays as the backstop for a slow render.
            Unit.After = ["sops-nix.service"];
            Unit.Wants = ["sops-nix.service"];
            Service = {
              ExecStart = "${identityAgent}/bin/git-identity-agent";
              ExecStartPost = "${addIdentityKey}/bin/add-git-identity-key";
              Restart = "on-failure";
            };
            Install.WantedBy = ["default.target"];
          };
        };
      })

      (lib.mkIf isDarwin {
        launchd.agents = {
          publish-git-identity = {
            enable = true;
            config = {
              ProgramArguments = ["${publishIdentity}/bin/publish-git-identity"];
              KeepAlive.SuccessfulExit = false;
              RunAtLoad = true;
            };
          };

          git-identity-agent = {
            enable = true;
            config = {
              ProgramArguments = ["${identityAgent}/bin/git-identity-agent"];
              KeepAlive = true;
              RunAtLoad = true;
            };
          };

          add-git-identity-key = {
            enable = true;
            config = {
              ProgramArguments = ["${addIdentityKey}/bin/add-git-identity-key"];
              KeepAlive.SuccessfulExit = false;
              RunAtLoad = true;
            };
          };
        };
      })
    ]))
  ];
}

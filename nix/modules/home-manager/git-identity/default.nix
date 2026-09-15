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

  publishIdentity = pkgs.writeShellApplication {
    name = "publish-git-identity";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      for _attempt in $(seq 1 30); do
        if [ -r ${config.sops.templates."git-identity.inc".path} ] \
          && [ -r ${config.sops.templates."git-allowed-signers".path} ]; then
          break
        fi
        sleep 1
      done

      publish() {
        rm -f "$2"
        install -D -m 0444 "$1" "$2"
      }

      publish ${config.sops.templates."git-identity.inc".path} ${identityDirectory}/git-identity.inc
      publish ${config.sops.templates."git-allowed-signers".path} ${identityDirectory}/allowed-signers
    '';
  };

  # Dedicated agent, not a relay into the interactive one -- gcr auto-loads any ~/.ssh/*.pub key, so a relay would leak whatever else it later holds.
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
      for _attempt in $(seq 1 30); do
        [ -S ${identitySocket} ] && break
        sleep 1
      done

      SSH_AUTH_SOCK=${identitySocket} ssh-add ${lib.escapeShellArg cfg.keyPath}
    '';
  };

  # Pins signing to the identity agent regardless of the caller's SSH_AUTH_SOCK -- ssh-keygen needs an agent to sign from a plain public key file.
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
      description = "The identity key's public key, in authorized_keys format.";
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
      # Derived, not configuration -- exposed so consumers do not re-derive where the
      # identity lives. `readOnly` only enforces a single definition: keep this the sole
      # unconditional one, and never give either a `default` (it would count as a second).
      preferences.gitIdentity = {
        directory = identityDirectory;
        socket = identitySocket;
      };
    }

    (lib.mkIf cfg.enable (lib.mkMerge [
      {
        # Every sshHost connection uses this identity, not gcr's default -- unlike github-secrets, no alias needed since it should apply everywhere.
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
          "git-allowed-signers".content = ''
            ${cfg.email} namespaces="git" ${cfg.publicKey}
          '';

          "git-identity.inc".content = ''
            [user]
              email = ${cfg.email}
              signingkey = ${cfg.keyPath}.pub
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

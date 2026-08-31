{
  config,
  lib,
  pkgs,
  ...
}: let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  identityDirectory = "${config.xdg.configHome}/git-identity";
  signingSocket = "${identityDirectory}/ssh-agent.sock";
  resolveSigningTarget =
    if isDarwin
    then ''
      if [ -z "$target" ] || [ "$target" = ${lib.escapeShellArg signingSocket} ]; then
        target="$(/bin/launchctl getenv SSH_AUTH_SOCK)"
      fi
      if [ "$target" = ${lib.escapeShellArg signingSocket} ]; then
        target=""
      fi
    ''
    else ''
      if [ -z "$target" ] || [ "$target" = ${lib.escapeShellArg signingSocket} ]; then
        target="/run/user/$(id -u)/gcr/ssh"
      fi
    '';

  publishIdentity = pkgs.writeShellApplication {
    name = "publish-git-identity";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      for _attempt in $(seq 1 30); do
        if [ -r ${config.sops.templates."git-work.inc".path} ] \
          && [ -r ${config.sops.templates."git-allowed-signers".path} ] \
          && [ -r ${config.sops.templates."git-signing-key".path} ]; then
          break
        fi
        sleep 1
      done

      publish() {
        rm -f "$2"
        install -D -m 0444 "$1" "$2"
      }

      publish ${config.sops.templates."git-work.inc".path} ${identityDirectory}/git-work.inc
      publish ${config.sops.templates."git-allowed-signers".path} ${identityDirectory}/allowed-signers
      publish ${config.sops.templates."git-signing-key".path} ${identityDirectory}/signing-key.pub
    '';
  };

  signingRelay = pkgs.writeShellApplication {
    name = "git-signing-agent-relay";
    runtimeInputs = [pkgs.coreutils pkgs.socat];
    text = ''
      target="''${SSH_AUTH_SOCK:-}"
      ${resolveSigningTarget}
      if [ -z "$target" ] || [ ! -S "$target" ]; then
        echo "git signing relay: SSH agent socket is unavailable" >&2
        exit 1
      fi

      mkdir -p ${identityDirectory}
      rm -f ${signingSocket}
      exec socat \
        UNIX-LISTEN:${signingSocket},fork,mode=0600 \
        UNIX-CONNECT:"$target"
    '';
  };
in
  lib.mkMerge [
    {
      sops.templates = {
        "git-allowed-signers".content = ''
          ${config.sops.placeholder.email} namespaces="git" ${config.sops.placeholder.public_key}
        '';

        "git-signing-key".content = ''
          ${config.sops.placeholder.public_key}
        '';

        "git-work.inc".content = ''
          [user]
            email = ${config.sops.placeholder.email}
            signingkey = ${identityDirectory}/signing-key.pub
          [gpg]
            format = ssh
          [gpg "ssh"]
            allowedSignersFile = ${identityDirectory}/allowed-signers
          [commit]
            gpgsign = true
          [tag]
            gpgsign = true
        '';
      };
    }

    # Linux sops-nix renders through a user service, so publishing belongs after
    # that service rather than in a racing Home Manager activation entry.
    (lib.mkIf (!isDarwin) {
      systemd.user.services = {
        sops-nix.Service.ExecStartPost = ["${publishIdentity}/bin/publish-git-identity"];

        git-signing-agent-relay = {
          Unit = {
            Description = "Stable SSH-agent socket for sandboxed Git signing";
            After = ["sops-nix.service"];
          };
          Service = {
            ExecStart = "${signingRelay}/bin/git-signing-agent-relay";
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

        git-signing-agent-relay = {
          enable = true;
          config = {
            ProgramArguments = ["${signingRelay}/bin/git-signing-agent-relay"];
            KeepAlive = true;
            RunAtLoad = true;
          };
        };
      };
    })
  ]

# Root installer for the standalone Home Manager host.
{
  inputs,
  lib,
  pkgs,
  homeDirectory,
}: let
  files = import ../modules/shared/agents/policy/managed-files.nix {inherit homeDirectory inputs lib pkgs;};
in
  pkgs.writeShellApplication {
    name = "install-agent-policy";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      if [ "$(id -u)" -ne 0 ]; then
        echo "install-agent-policy: must run as root" >&2
        echo "  sudo nix run ./nix#install-agent-policy" >&2
        exit 1
      fi

      install -Dm444 "${files.claude}" /etc/claude-code/managed-settings.json
      install -Dm444 "${files.opencode}" /etc/opencode/opencode.json
      install -Dm444 "${files.codex}" /etc/codex/requirements.toml

      echo "installed managed Claude, Codex, and OpenCode policies" >&2
    '';
  }

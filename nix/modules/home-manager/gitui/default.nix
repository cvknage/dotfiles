# gitui, wrapped in the git identity's context when that identity is enabled.
#
# gitui (libgit2) can't evaluate includeIf hasconfig (libgit2/libgit2#6641), so the wrapper
# greps the remote with real `git` and writes a plain include into the repo's local config
# instead. gitui's own SSH signing also needs a real private key next to user.signingkey
# (gitui-org/gitui#2184) -- the identity publishes a private-key symlink next to
# <identityDirectory>/identity.pub for exactly that (see the git-identity module).
{
  config,
  lib,
  pkgs,
  ...
}: let
  identity = config.preferences.gitIdentity;

  # Installed as an ordinary package, not through `nixpkgs.overlays`: under
  # home-manager.useGlobalPkgs that option is declared but never read, so an overlay applied
  # on the Fedora and standalone tiers and silently did not on NixOS.
  gituiWrapper = pkgs.writeShellApplication {
    name = "gitui";
    runtimeInputs = [pkgs.coreutils pkgs.git pkgs.gnugrep];
    text = ''
      include_path=${lib.escapeShellArg "${identity.directory}/git-identity.inc"}
      remote_match="$(cat ${lib.escapeShellArg identity.remoteMatchPath})"

      repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
      if [ -n "$repo_root" ] \
        && git -C "$repo_root" config --get-regexp '^remote\..*\.url$' 2>/dev/null \
          | grep -qF -e ${lib.escapeShellArg (identity.sshHost + ":")}"$remote_match/" \
                     -e ${lib.escapeShellArg (identity.sshHost + "/")}"$remote_match/"; then
        if ! git -C "$repo_root" config --get-all include.path 2>/dev/null \
          | grep -qxF "$include_path"; then
          git -C "$repo_root" config --add include.path "$include_path"
        fi
        # Only for this identity's own repos -- elsewhere keeps the inherited SSH_AUTH_SOCK.
        export SSH_AUTH_SOCK=${lib.escapeShellArg identity.socket}
      fi

      # -a keeps argv[0] as "gitui" so tmux-resurrect's anchored process match still finds it.
      exec -a gitui ${pkgs.gitui}/bin/gitui "$@"
    '';
  };
in {
  imports = [../git-identity];

  config = lib.mkMerge [
    (lib.mkIf identity.enable {home.packages = [gituiWrapper];})
    (lib.mkIf (!identity.enable) {home.packages = [pkgs.gitui];})
  ];
}

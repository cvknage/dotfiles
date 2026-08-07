{
  pkgs,
  user,
  ...
}: let
  home =
    if pkgs.stdenv.isDarwin
    then "/Users/${user}"
    else "/home/${user}";
in {
  # System-wide alias for fetching the secrets flake input, so it also works
  # for root during sudo rebuilds.
  programs.ssh.extraConfig = ''
    Host github-secrets
      HostName github.com
      User git
      IdentityFile ${home}/.ssh/dotfiles-secrets
      IdentitiesOnly yes
  '';
}

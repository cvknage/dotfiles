# Single source for the github-secrets ssh alias. Rendered into /etc/ssh by
# ./secrets-ssh.nix and into ~/.ssh/config by homes/shared/secrets-ssh.nix.
home: {
  host = "github-secrets";
  settings = {
    HostName = "github.com";
    User = "git";
    IdentityFile = "${home}/.ssh/dotfiles-secrets";
    IdentitiesOnly = "yes";
  };
}

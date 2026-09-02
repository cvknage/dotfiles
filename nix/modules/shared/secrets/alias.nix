# Single source for the github-secrets SSH alias.
home: {
  host = "github-secrets";
  settings = {
    HostName = "github.com";
    User = "git";
    IdentityFile = "${home}/.ssh/keys/dotfiles-secrets";
    IdentitiesOnly = "yes";
  };
}

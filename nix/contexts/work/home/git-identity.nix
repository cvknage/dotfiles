{config, ...}: {
  preferences.gitIdentity = {
    enable = true;
    email = config.sops.placeholder.email;
    publicKey = config.sops.placeholder.github_public_key;
    keyPath = "${config.home.homeDirectory}/.ssh/keys/github";
    remoteMatch = "secomea-dev";
  };
}

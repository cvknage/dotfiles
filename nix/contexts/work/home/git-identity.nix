{config, ...}: {
  preferences.gitIdentity = {
    enable = true;
    email = config.sops.placeholder.email;
    publicKey = config.sops.placeholder.github_public_key;
    keyPath = config.sops.secrets.github_private_key.path;
    remoteMatch = config.sops.placeholder.github_org;
  };
}

{...}: {
  imports = [
    ./home-manager
    ./secrets-ssh.nix
    ./stable-packages
    ./system.nix
  ];
}

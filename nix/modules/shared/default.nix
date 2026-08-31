{...}: {
  imports = [
    ../agents/system.nix
    ./home-manager
    ./secrets-ssh.nix
    ./stable-packages
    ./system.nix
  ];
}

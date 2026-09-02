{...}: {
  imports = [
    ../agents/system.nix
    ./home-manager
    ./secrets
    ./stable-packages
    ./system.nix
  ];
}

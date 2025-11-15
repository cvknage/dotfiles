{
  description = "home-manager configuration for nix-darwin and gnu/linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "github:cvknage/dotfiles-secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    tuxedo-nixos.url = "github:sylvesterroos/tuxedo-nixos";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    nix-darwin,
    nix-homebrew,
    tuxedo-nixos,
    ...
  }: let
    owner = "Christophe Knage";
    user = "chris";
    darwinArchitecture = "aarch64-darwin";
    linuxArchitecture = "x86_64-linux";
    extraArgs = {inherit inputs user;};
    sharedModules = [
      ./modules/shared
    ];
    nixosModules = [
      home-manager.nixosModules.home-manager
    ];
    darwinModules = [
      home-manager.darwinModules.home-manager
      nix-homebrew.darwinModules.nix-homebrew
      ./modules/darwin
    ];
  in {
    darwinConfigurations = {
      logic = nix-darwin.lib.darwinSystem {
        system = darwinArchitecture;
        specialArgs = extraArgs // {inherit self;} // {hostPlatform = darwinArchitecture;};
        modules =
          [
            ./hosts/logic/configuration.nix
            {
              home-manager = {
                users.${user} = import ./homes/private;
                extraSpecialArgs = extraArgs;
              };
            }
          ]
          ++ sharedModules
          ++ darwinModules;
      };
    };

    nixosConfigurations = {
      penguin-tuxedo = nixpkgs.lib.nixosSystem {
        system = linuxArchitecture;
        specialArgs = extraArgs // {inherit owner;} // {hostPlatform = linuxArchitecture;};
        modules =
          [
            ./hosts/penguin-tuxedo/configuration.nix
            {
              home-manager = {
                users.${user} = import ./homes/work;
                extraSpecialArgs = extraArgs;
              };
            }
            tuxedo-nixos.nixosModules.default
            {
              hardware.tuxedo-control-center = {
                enable = true;
                package = tuxedo-nixos.packages.${linuxArchitecture}.default;
              };
            }
          ]
          ++ sharedModules
          ++ nixosModules;
      };
    };

    homeConfigurations."${user}@full-tuxedo" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${linuxArchitecture};
      modules = [./homes/work];
      extraSpecialArgs = extraArgs;
    };
  };
}

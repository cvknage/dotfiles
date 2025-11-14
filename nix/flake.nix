{
  description = "home-manager configuration for nix-darwin and gnu/linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs_gitui0_26_3.url = "github:NixOS/nixpkgs/c792c60b8a97daa7efe41a6e4954497ae410e0c1";
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
    mac-app-util.url = "github:hraban/mac-app-util";
    tuxedo-nixos.url = "github:sylvesterroos/tuxedo-nixos";
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    home-manager,
    mac-app-util,
    tuxedo-nixos,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    homebrew-bundle,
    ...
  }: let
    owner = "Christophe Knage";
    user = "chris";
    darwinArchitecture = "aarch64-darwin";
    linuxArchitecture = "x86_64-linux";
    extraArgs = {inherit inputs user;};
  in {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#logic
    darwinConfigurations."logic" = nix-darwin.lib.darwinSystem {
      system = darwinArchitecture;
      specialArgs = extraArgs // {inherit self;} // {hostPlatform = darwinArchitecture;};
      modules = [
        ./hosts/logic/configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.${user} = import ./homes/private/home.nix;

          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
          home-manager.extraSpecialArgs = extraArgs;

          home-manager.sharedModules = [
            # (Nix) Utilities for Mac App launcher
            # https://github.com/hraban/mac-app-util
            mac-app-util.homeManagerModules.default

            (args:
              inputs.secrets.homeManagerModules.default {
                sops-nix = inputs.sops-nix;
                keyFile = inputs.nixpkgs.lib.mkDefault "${args.config.xdg.configHome}/sops/age/keys.txt";
                secrets = {
                  sheet_music = {};
                };
              })
          ];
        }

        # (Nix) Utilities for Mac App launcher
        # https://github.com/hraban/mac-app-util
        mac-app-util.darwinModules.default

        # Install Homebrew - packages are declared in darwinConfiguration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;

            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            enableRosetta = false;

            # User owning the Homebrew prefix
            inherit user;

            # Declarative tap management
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
              "homebrew/homebrew-bundle" = homebrew-bundle;
            };

            # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
            mutableTaps = false;
          };
        }
      ];
    };

    nixosConfigurations."penguin-tuxedo" = nixpkgs.lib.nixosSystem {
      system = linuxArchitecture;
      specialArgs = extraArgs // {inherit owner;} // {hostPlatform = linuxArchitecture;};
      modules = [
        ./hosts/penguin-tuxedo/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.${user} = import ./homes/work/home.nix;

          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
          home-manager.extraSpecialArgs = extraArgs;

          home-manager.sharedModules = [];
        }
        tuxedo-nixos.nixosModules.default
        {
          hardware.tuxedo-control-center.enable = true;
          hardware.tuxedo-control-center.package = tuxedo-nixos.packages.${linuxArchitecture}.default;
        }
      ];
    };

    homeConfigurations."${user}@full-tuxedo" = home-manager.lib.homeManagerConfiguration {
      # Home-Manager requires 'pkgs' instance
      pkgs = nixpkgs.legacyPackages.${linuxArchitecture};

      # Specify your home configuration modules here, for example,
      # the path to your home.nix.
      modules = [./homes/work/home.nix];

      # Optionally use extraSpecialArgs
      # to pass through arguments to home.nix
      extraSpecialArgs = extraArgs;
    };
  };
}

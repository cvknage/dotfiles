{
  description = "home-manager configuration for nix-darwin and gnu/linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util.url = "github:hraban/mac-app-util";
    tuxedo-nixos.url = "github:sylvesterroos/tuxedo-nixos";
    wezterm.url = "github:wez/wezterm?dir=nix";
    ghostty.url = "github:ghostty-org/ghostty";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, mac-app-util, tuxedo-nixos, ... }:
  let
    owner = "Christophe Knage";
    user = "chris";
    darwinArchitecture = "aarch64-darwin";
    linuxArchitecture = "x86_64-linux";
    extraArgs = { inherit inputs user; };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#logic
    darwinConfigurations."logic" = nix-darwin.lib.darwinSystem {
      system = darwinArchitecture;
      specialArgs = extraArgs // { inherit self; } // { hostPlatform = darwinArchitecture; };
      modules = [
        ./hosts/logic/configuration.nix
        home-manager.darwinModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user} = import ./homes/private/home.nix;

          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
          home-manager.extraSpecialArgs = extraArgs;

          # (Nix) Utilities for Mac App launcher
          # https://github.com/hraban/mac-app-util
          home-manager.sharedModules = [
            mac-app-util.homeManagerModules.default
          ];
        }

        # (Nix) Utilities for Mac App launcher
        # https://github.com/hraban/mac-app-util
        mac-app-util.darwinModules.default
      ];
    };

    homeConfigurations."${user}@logic" = home-manager.lib.homeManagerConfiguration {
      # Home-Manager requires 'pkgs' instance
      pkgs = nixpkgs.legacyPackages.${darwinArchitecture};

      # Specify your home configuration modules here, for example,
      # the path to your home.nix.
      modules = [
        ./homes/private/home.nix

        # (Nix) Utilities for Mac App launcher
        # https://github.com/hraban/mac-app-util
        mac-app-util.homeManagerModules.default
      ];

      # Optionally use extraSpecialArgs
      # to pass through arguments to home.nix
      extraSpecialArgs = extraArgs;
    };

    nixosConfigurations."penguin-tuxedo" = nixpkgs.lib.nixosSystem {
      system = linuxArchitecture;
      specialArgs = extraArgs // { inherit owner; } // { hostPlatform = linuxArchitecture; };
      modules = [
        ./hosts/penguin-tuxedo/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user} = import ./homes/work/home.nix;

          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
          home-manager.extraSpecialArgs = extraArgs;
        }
        tuxedo-nixos.nixosModules.default
        {
          hardware.tuxedo-control-center.enable = true;
          hardware.tuxedo-control-center.package = tuxedo-nixos.packages.${linuxArchitecture}.default;
        }
      ];
    };

    homeConfigurations."${user}@penguin-tuxedo" = home-manager.lib.homeManagerConfiguration {
      # Home-Manager requires 'pkgs' instance
      pkgs = nixpkgs.legacyPackages.${linuxArchitecture};

      # Specify your home configuration modules here, for example,
      # the path to your home.nix.
      modules = [ ./homes/work/home.nix ];

      # Optionally use extraSpecialArgs
      # to pass through arguments to home.nix
      extraSpecialArgs = extraArgs;
    };
  };
}

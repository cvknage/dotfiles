{
  description = "home-manager configuration for nix-darwin and gnu/linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util.url = "github:hraban/mac-app-util";
    wezterm.url = "github:wez/wezterm?dir=nix";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, mac-app-util, ... }:
  let
    user = "chris";
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
    extraArgs = { inherit inputs user; };
    configuration = { pkgs, user, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [
      ];

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;
      programs.zsh = {
        enable = true;
        promptInit = "PS1=\"%n@%m %1~ %# \"";
      };

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = system;

      # Home-Manager needs this value to work with nix-darwin.
      users.users.${user}.home = "/Users/${user}";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#logic
    darwinConfigurations."logic" = nix-darwin.lib.darwinSystem {
      system = system;
      specialArgs = extraArgs;
      modules = [
        configuration
        home-manager.darwinModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user} = import ./logic/home.nix;

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
      inherit pkgs; # inherit pkgs from let pkgs

      # Specify your home configuration modules here, for example,
      # the path to your home.nix.
      modules = [
        ./logic/home.nix 

        # (Nix) Utilities for Mac App launcher
        # https://github.com/hraban/mac-app-util
        mac-app-util.homeManagerModules.default
      ];

      # Optionally use extraSpecialArgs
      # to pass through arguments to home.nix
      extraSpecialArgs = extraArgs;
    };

    homeConfigurations."${user}@penguin-tuxedo" = home-manager.lib.homeManagerConfiguration {
      # Home-Manager requires 'pkgs' instance
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Specify your home configuration modules here, for example,
      # the path to your home.nix.
      modules = [ ./tux/home.nix ];

      # Optionally use extraSpecialArgs
      # to pass through arguments to home.nix
      extraSpecialArgs = extraArgs;
    };
  };
}

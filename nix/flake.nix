{
  description = "home-manager configuration for nix-darwin and gnu/linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      # Private repo, fetched with a deploy key via ./scripts/secrets-bootstrap.sh
      url = "git+ssh://github-secrets/cvknage/dotfiles-secrets";
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
    tuxedo-nixos = {
      url = "github:sund3RRR/tuxedo-nixos";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    nix-darwin,
    nix-homebrew,
    system-manager,
    tuxedo-nixos,
    ...
  }: let
    owner = "Christophe Knage";
    privateUser = "chris";
    workUser = "ckn";
    darwinArchitecture = "aarch64-darwin";
    linuxArchitecture = "x86_64-linux";
    workHomeConfiguration = "${workUser}@work";
    inherit (nixpkgs) lib;
    mkArgs = user: {
      inherit inputs user;
      homeContext = import ./lib/home-context.nix;
    };
    privateArgs = mkArgs privateUser;
    workArgs = mkArgs workUser;
    sharedModules = [
      ./modules/shared
    ];
    nixosModules = [
      home-manager.nixosModules.home-manager
      ./modules/nixos
    ];
    darwinModules = [
      home-manager.darwinModules.home-manager
      nix-homebrew.darwinModules.nix-homebrew
      ./modules/darwin
    ];
  in {
    formatter.${darwinArchitecture} = nixpkgs.legacyPackages.${darwinArchitecture}.alejandra;
    formatter.${linuxArchitecture} = nixpkgs.legacyPackages.${linuxArchitecture}.alejandra;

    darwinConfigurations = {
      logic = nix-darwin.lib.darwinSystem {
        system = darwinArchitecture;
        specialArgs = privateArgs // {inherit self;};
        modules =
          [
            ./hosts/logic/configuration.nix
            {
              home-manager = {
                users.${privateUser} = import ./homes/private;
                extraSpecialArgs = privateArgs;
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
        specialArgs = privateArgs // {inherit owner;};
        modules =
          [
            ./hosts/penguin-tuxedo/configuration.nix
            {
              home-manager = {
                users.${privateUser} = import ./homes/work;
                extraSpecialArgs = privateArgs;
              };
            }
            tuxedo-nixos.nixosModules.default
          ]
          ++ sharedModules
          ++ nixosModules;
      };
    };

    # One per System Manager host. Fedora is experimental: System Manager only
    # asserts support for nixos, ubuntu and debian.
    systemConfigs = lib.genAttrs ["ubuntu" "fedora"] (host:
      system-manager.lib.makeSystemConfig {
        specialArgs = workArgs // {inherit self;};
        modules = [
          ./hosts/${host}/configuration.nix
        ];
      });

    # Shared by every standalone Linux work host, regardless of hostname or
    # distro. Standalone Home Manager cannot install the root-owned /etc policy.
    homeConfigurations.${workHomeConfiguration} = home-manager.lib.homeManagerConfiguration {
      # Mirror the shared system module's package configuration.
      pkgs = import nixpkgs {
        system = linuxArchitecture;
        config.allowUnfree = true;
        overlays = [(import ./overlays {inherit inputs;}).stable-packages];
      };
      modules = [
        ./homes/shared
        ./homes/work
        ./homes/work/generic-linux.nix
      ];
      extraSpecialArgs = workArgs;
    };

    apps.${linuxArchitecture} =
      {
        # Install the root-owned policy after standalone Home Manager switches.
        # Not needed where System Manager owns the /etc policy.
        install-agent-policy = {
          type = "app";
          meta.description = "Install the root-owned agent policy into /etc";
          program = lib.getExe (import ./apps/install-agent-policy.nix {
            inherit inputs lib;
            pkgs = nixpkgs.legacyPackages.${linuxArchitecture};
            homeDirectory = "/home/${workUser}";
          });
        };
      }
      # Both configuration tiers in one command, per System Manager host.
      // lib.mapAttrs' (host: _:
        lib.nameValuePair "${host}-rebuild" {
          type = "app";
          meta.description = "Apply the System Manager and Home Manager tiers on ${host}";
          program = lib.getExe (import ./lib/rebuild-app.nix {
            inherit inputs;
            systemConfig = host;
            homeConfiguration = workHomeConfiguration;
            pkgs = nixpkgs.legacyPackages.${linuxArchitecture};
            system = linuxArchitecture;
          });
        })
      self.systemConfigs;
  };
}

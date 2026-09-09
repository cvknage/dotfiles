{
  description = "home-manager configuration for nix-darwin and gnu/linux";

  nixConfig = {
    extra-substituters = ["https://cache.numtide.com"];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

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
    llm-agents = {
      # Not following: numtide's cache is only built against its own nixpkgs pin.
      url = "github:numtide/llm-agents.nix";
    };
    claude-pace = {
      # Claude Code statusline: https://github.com/Astro-Han/claude-pace
      url = "github:Astro-Han/claude-pace/v0.9.4";
      # url = "github:Astro-Han/claude-pace"; # main, untagged
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    nix-darwin,
    nix-homebrew,
    system-manager,
    ...
  }: let
    owner = "Christophe Knage";
    privateUser = "chris";
    workUser = "ckn";

    darwinArchitecture = "aarch64-darwin";
    linuxArchitecture = "x86_64-linux";
    inherit (nixpkgs) lib;

    mkArgs = user: {
      inherit inputs user;
      homeContext = import ./lib/home-context.nix;
    };
    privateArgs = mkArgs privateUser;
    workArgs = mkArgs workUser;

    # Like nixpkgs.lib.nixosSystem, but for System Manager machines.
    mkGenericLinuxSystem = import ./lib/mk-generic-linux-system.nix {
      inherit inputs nixpkgs;
    };

    sharedModules = [
      ./modules/shared
    ];
    systemModules = [
      ./modules/system
    ];
    nixosModules = [
      home-manager.nixosModules.home-manager
      ./modules/nixos
      ./modules/shared/desktops/gnome/system.nix
      ./contexts/shared/system/nixos
    ];
    darwinModules = [
      home-manager.darwinModules.home-manager
      nix-homebrew.darwinModules.nix-homebrew
      ./modules/darwin
      ./contexts/shared/system/darwin
    ];
    fedoraModules = [
      ./contexts/shared/system/fedora
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
            ./contexts/private/system/darwin.nix
            {
              home-manager = {
                users.${privateUser} = import ./contexts/private/home;
                extraSpecialArgs = privateArgs;
              };
            }
          ]
          ++ sharedModules
          ++ systemModules
          ++ darwinModules;
      };
    };

    nixosConfigurations = {
      penguin-tuxedo = nixpkgs.lib.nixosSystem {
        system = linuxArchitecture;
        specialArgs = privateArgs // {inherit owner;};
        modules =
          [
            ./hardware/tuxedo-stellaris-gen6
            ./contexts/work/system/nixos.nix
            {dotfiles.desktops.gnome.enable = true;}
            {
              home-manager = {
                users.${privateUser} = import ./contexts/work/home;
                extraSpecialArgs = privateArgs;
              };
            }
          ]
          ++ sharedModules
          ++ systemModules
          ++ nixosModules;
      };
    };

    # One per System Manager host: a machine-and-user bundle with both tiers.
    # Keys are short hostnames; the <distro>-rebuild app selects by them.
    # Fedora is experimental: System Manager only asserts support for nixos,
    # ubuntu and debian.
    linuxConfigurations = {
      ckn-laptop = mkGenericLinuxSystem {
        distro = "fedora";
        selinux = true;
        system = linuxArchitecture;
        specialArgs = workArgs // {inherit self;};
        modules =
          [
            {dotfiles.desktops.gnome.enable = true;}
            {
              home-manager = {
                users.${workUser} = import ./contexts/work/home;
                extraSpecialArgs = workArgs;
              };
            }
          ]
          ++ sharedModules
          ++ systemModules
          ++ fedoraModules;
      };
    };

    # Standalone Home Manager, kept as a backup for work hosts where
    # System Manager cannot be used at all.
    homeConfigurations."${workUser}@work" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${linuxArchitecture};
      modules =
        [
          ./contexts/shared/home/generic-linux.nix
          ./contexts/shared/home
          ./contexts/work/home
          {dotfiles.desktops.gnome.enable = true;}
        ]
        ++ sharedModules;
      extraSpecialArgs = workArgs;
    };

    apps.${linuxArchitecture} = {
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

      # The generic System Manager rebuild app; see the file for its CLI.
      linux-rebuild = {
        type = "app";
        meta.description = "Install <distro>-rebuild and apply the System Manager and Home Manager tiers";
        program = lib.getExe (import ./apps/rebuild.nix {
          inherit inputs;
          name = "linux-rebuild";
          pkgs = nixpkgs.legacyPackages.${linuxArchitecture};
          system = linuxArchitecture;
        });
      };
    };

    # Aliases each machine's System Manager config under `systemConfigs`, where the CLI's flake resolution expects it.
    systemConfigs = lib.mapAttrs (_: cfg: cfg.system) self.linuxConfigurations;
  };
}

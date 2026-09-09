# Wraps a System Manager machine like nixpkgs.lib.nixosSystem wraps NixOS.
#
# On NixOS/nix-darwin, `home-manager.nixosModules.home-manager` /
# `darwinModules.home-manager` hook into the *same* module evaluation that
# builds the system, so the home tier just reads `config.home-manager` off
# it directly. System Manager has no such integration module, so this file
# stands in for it as `homeManagerIntegration` below: it evaluates the
# machine's `modules` a second time, on the side, purely to resolve the
# `home-manager.*` (and `nixpkgs.overlays`) values those modules set, then
# hand-feeds them into a separate, real
# `home-manager.lib.homeManagerConfiguration` call below to actually build
# the `home` output.
#
# Because the *real* System Manager pass (`system` below) also receives the
# raw `modules`, and System Manager's module system has no `home-manager`
# option either, `homeManagerOptionShim` declares it there too so that pass
# doesn't fail with "option does not exist" - the value is simply discarded
# there; `homeManagerIntegration` is what actually consumes it. (`nixpkgs.*`
# needs no such shim in the real pass: System Manager already declares a
# real `nixpkgs` option there, e.g. `nixpkgs.hostPlatform` below.)
#
# `linux-rebuild` (nix/apps/rebuild.nix) applies the `system` and `home`
# outputs of this function in order, and the home tier installs its
# <distro>-rebuild alias.
{
  inputs,
  nixpkgs,
}: let
  lib = nixpkgs.lib;

  # Inert in the real System Manager pass (see header) - only
  # `homeManagerIntegration` reads it for real.
  homeManagerOptionShim = {
    options.home-manager = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
    };
  };
  # Only for `homeManagerIntegration`: lets it read the composition's nixpkgs overlays/config.
  nixpkgsOptionShim = {
    options.nixpkgs = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
    };
  };
in
  {
    distro, # System Manager distro; names the <distro>-rebuild alias the home tier installs as a package
    selinux ? false, # relabel the store closure for SELinux-enforcing distros
    system,
    specialArgs ? {},
    modules ? [],
  }: let
    # Stands in for the `config.home-manager` that NixOS/nix-darwin's real
    # integration module would read off the system's own evaluation; see
    # header. Never built, only read from below.
    homeManagerIntegration =
      (lib.evalModules {
        inherit specialArgs;
        modules =
          modules
          ++ [
            homeManagerOptionShim
            nixpkgsOptionShim
            # Modules like systems/fedora declare `pkgs`; the system tier's
            # module system provides it, this side pass does not.
            {pkgs = nixpkgs.legacyPackages.${system};}
            # This side pass only reads the home-manager block and the
            # nixpkgs overlays; system-tier modules define options that do
            # not exist in this bare module set, so the undeclared-option
            # check is off.
            {_module.check = false;}
          ];
      }).config;

    homeManagerConfig = homeManagerIntegration.home-manager or {};
    homeUsers = homeManagerConfig.users or {};
    # The home tier builds its own pkgs set, so it inherits the overlays the
    # composition's modules set (the standalone useGlobalPkgs equivalent).
    overlays = (homeManagerIntegration.nixpkgs or {}).overlays or [];
    # The composition's desktop switch, propagated to the home tier.
    homeGnomeEnabled = (homeManagerIntegration.dotfiles or {}).desktops.gnome.enable or false;
  in {
    inherit distro selinux;

    system = inputs.system-manager.lib.makeSystemConfig {
      inherit specialArgs;
      modules =
        [
          homeManagerOptionShim
          {nixpkgs.hostPlatform = system;}
        ]
        ++ modules;
    };

    home = let
      # The home tier instantiates its own nixpkgs with the overlays and
      # config the composition's modules set (the standalone useGlobalPkgs
      # equivalent).
      pkgs = import inputs.nixpkgs {
        inherit system;
        inherit overlays;
        config = homeManagerIntegration.nixpkgs.config or {};
      };
      users = lib.mapAttrs (_: homeModules:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules =
            [homeModules]
            ++ (homeManagerConfig.sharedModules or [])
            ++ [
              # Every System Manager host runs standalone Home Manager on a
              # non-NixOS distro, so the genericLinux integration applies.
              ../contexts/shared/home/generic-linux.nix
              # Propagate the composition's desktop switch to the home tier.
              {dotfiles.desktops.gnome.enable = lib.mkDefault homeGnomeEnabled;}
              # Installs <distro>-rebuild as a home package, so it lands in the already-on-PATH profile like darwin-rebuild (see nix/apps/rebuild.nix).
              ({pkgs, ...}: {
                home.packages = [
                  (pkgs.writeShellScriptBin "${distro}-rebuild" ''
                    exec nix run "$HOME/.dotfiles/nix#linux-rebuild" -- "$@"
                  '')
                ];
              })
            ];
          extraSpecialArgs = homeManagerConfig.extraSpecialArgs or {};
        })
      homeUsers;
    in
      # Single-user machines for now; extend the bundle when a multi-user
      # machine arrives.
      assert lib.assertMsg (lib.length (lib.attrValues users) == 1)
      "mkGenericLinuxSystem: expected exactly one home-manager.users entry, got: ${toString (lib.attrNames users)}";
        builtins.head (lib.attrValues users);
  }

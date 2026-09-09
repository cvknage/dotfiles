# Wraps a System Manager machine like nixpkgs.lib.nixosSystem wraps NixOS.
# System Manager cannot embed the home tier, so the home-manager block in the
# modules builds it as a sibling generation; the <distro>-rebuild app applies
# the two in order.
{
  inputs,
  nixpkgs,
}: let
  lib = nixpkgs.lib;
  # Declares the home-manager options the composition's `home-manager` block
  # sets. System Manager knows nothing of them, so they are inert in the
  # system tier; the home tier below reads them back.
  homeManagerOptions = {
    options.home-manager = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
    };
  };
  # Same idea for reading the composition's nixpkgs settings (overlays) back.
  nixpkgsOptions = {
    options.nixpkgs = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
    };
  };
in
  {
    distro, # System Manager distro; names the <distro>-rebuild app
    selinux ? false, # relabel the store closure for SELinux-enforcing distros
    system,
    specialArgs ? {},
    modules ? [],
  }: let
    extracted =
      (lib.evalModules {
        inherit specialArgs;
        modules =
          modules
          ++ [
            homeManagerOptions
            nixpkgsOptions
            # Modules like systems/fedora declare `pkgs`; the system tier's
            # module system provides it, this extraction pass does not.
            {pkgs = nixpkgs.legacyPackages.${system};}
            # The extraction only reads the home-manager block and the nixpkgs
            # overlays; system-tier modules define options that do not exist
            # in this bare module set, so the undeclared-option check is off.
            {_module.check = false;}
          ];
      }).config;

    homeManagerConfig = extracted.home-manager or {};
    homeUsers = homeManagerConfig.users or {};
    # The home tier builds its own pkgs set, so it inherits the overlays the
    # composition's modules set (the standalone useGlobalPkgs equivalent).
    overlays = (extracted.nixpkgs or {}).overlays or [];
    # The composition's desktop switch, propagated to the home tier.
    homeGnomeEnabled = (extracted.dotfiles or {}).desktops.gnome.enable or false;
  in {
    inherit distro selinux;

    system = inputs.system-manager.lib.makeSystemConfig {
      inherit specialArgs;
      modules =
        [
          homeManagerOptions
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
        config = extracted.nixpkgs.config or {};
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
            ];
          extraSpecialArgs = homeManagerConfig.extraSpecialArgs or {};
        })
      homeUsers;
    in
      # Single-user machines for now; extend the bundle when a multi-user
      # machine arrives.
      assert lib.length (lib.attrValues users) == 1;
        builtins.head (lib.attrValues users);
  }

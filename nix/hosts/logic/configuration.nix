{ config, self, pkgs, user, hostPlatform, ... }: 

{
  imports = [
    # Include cachix references
    ../cachix.nix
  ];

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = [
  ];

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Enable alternative shell support in nix-darwin.
  # programs.fish.enable = true;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = hostPlatform;

  # Home-Manager needs this value to work with nix-darwin.
  users.users.${user}.home = "/Users/${user}";

  # Enable nix-darwin to manage Homebrew, Mac App Store apps and Docker containers.
  homebrew = {
    enable = true;

    # Whether to enable Homebrew to auto-update itself and all formulae when you manually invoke commands like brew install, brew upgrade, brew tap, and brew bundle [install].
    global.autoUpdate = false;

    onActivation = {
      # Whether to enable Homebrew to auto-update itself and all formulae during nix-darwin system activation. The default is false so that repeated invocations of darwin-rebuild switch are idempotent.
      autoUpdate = false;

      # Whether to enable Homebrew to upgrade outdated formulae and Mac App Store apps during nix-darwin system activation. The default is false so that repeated invocations of darwin-rebuild switch are idempotent.
      upgrade = false;

      # This uninstalls all formulae not listed in the generated Brewfile, and if the formula is a cask, removes all files associated with that cask.
      cleanup = "zap";
    };

    # Pass in all taps from nix-homebrew.
    taps = builtins.attrNames config.nix-homebrew.taps;

    # List of Homebrew formulae to install.
    brews = [];

    # List of Homebrew casks to install.
    casks = [
      "ghostty" # Ghostty from nixpkgs is marked as broken for darwin
    ];

    # Applications to install from Mac App Store using mas.
    masApps = {};
  };
}


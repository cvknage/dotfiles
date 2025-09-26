{
  config,
  self,
  user,
  hostPlatform,
  ...
}: {
  imports = [
    # Enable flakes
    ../flakes.nix

    # Allow unfree packages
    ../../allow-unfree.nix
  ];

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = [
  ];

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

    # The user that owns the Homebrew installation. In most cases this should be the normal user account that you installed Homebrew as.
    user = "${user}";

    # Whether to enable Homebrew to auto-update itself and all formulae when you manually invoke commands like brew install, brew upgrade, brew tap, and brew bundle [install].
    global.autoUpdate = false;

    onActivation = {
      # Whether to enable Homebrew to auto-update itself and all formulae during nix-darwin system activation. The default is false so that repeated invocations of darwin-rebuild switch are idempotent.
      autoUpdate = false;

      # Whether to enable Homebrew to upgrade outdated formulae and Mac App Store apps during nix-darwin system activation. The default is false so that repeated invocations of darwin-rebuild switch are idempotent.
      # To upgrade all casks: brew upgrade --cask --greedy
      upgrade = false;

      # This uninstalls all formulae not listed in the generated Brewfile, and if the formula is a cask, removes all files associated with that cask.
      cleanup = "zap";
    };

    # Pass in all taps from nix-homebrew.
    taps = builtins.attrNames config.nix-homebrew.taps;

    # List of Homebrew formulae to install.
    brews = [
      # "mas" # When the option "masApps" is used, "mas" is automatically added to homebrew.brews.
    ];

    # List of Homebrew casks to install.
    casks = [
      # Utilities
      "senadevicemanager"
      "tm-error-logger"
      "appcleaner"
      "ente-auth"
      "garmin-express"
      "openmtp"

      # Developer Tools
      "ghostty"
      "wezterm"
      "raspberry-pi-imager"
      "cyberduck"
      "utm"

      # Notes
      "obsidian"

      # Creative
      "gimp"
      "imageoptim"

      # Browsers
      "firefox"
      "ungoogled-chromium"

      # Audio & Video Tools
      "iina"
      "xld"
    ];

    # Applications to install from Mac App Store using mas.
    masApps = {
      # Core Tools
      "Amphetamine" = 937984704;
      "The Unarchiver" = 425424353;
      "BetterSnapTool" = 417375580;
      "EasyFind" = 411673888;

      # Safari Extensions
      "Surfingkeys" = 1609752330;
      "Dark Reader for Safari" = 1438243180;

      # Developer Tools
      "Xcode" = 497799835;
      "CotEditor" = 1024640650;

      # Creative
      "Pixelmator Pro" = 1289583905;

      # Maps
      "Guru Maps" = 321745474;
      # "Scenic Motorcycle Navigation" = 1089668246; # iPad/iPhone Apps not supported - https://github.com/mas-cli/mas/issues/321

      # Tesla
      "Dash View" = 1484225024;
      "Auth for Tesla" = 1552058613;

      # Hardware Devices
      "Keymapp" = 6472865291;
      "Brother iPrint&Scan" = 1193539993;
      "ASUS Device Discovery" = 995124504;
      "ASUS Firmware Restoration" = 1020519014;

      # Office
      "Pages" = 409201541;
      "Numbers" = 409203825;
      "Keynote" = 409183694;
      "Msg Viewer Pro" = 1019539949;

      # Finance
      "Copay" = 1440201813;
    };
  };
}

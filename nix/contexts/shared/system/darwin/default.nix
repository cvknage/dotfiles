# Base system tier every macOS machine gets.
{
  config,
  self,
  user,
  ...
}: {
  imports = [
    ../../../../../kanata/kanata_install_darwin.nix
  ];

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  system.primaryUser = user;

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

    # Casks and Mac App Store apps are per-role; declare them in
    # nix/contexts/<role>/system/darwin.nix.
  };
}

# Private-role system bits for macOS hosts.
{pkgs, ...}: {
  # Start ollama serve on login so the CLI works out of the box.
  launchd.user.agents.ollama = {
    serviceConfig = {
      ProgramArguments = ["${pkgs.ollama}/bin/ollama" "serve"];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # System identity: the state schema of the machine's first install.
  system.stateVersion = 5;

  # Enable nix-darwin to manage Homebrew casks and Mac App Store apps; the
  # homebrew mechanics (enable, taps, cleanup) come from
  # contexts/shared/system/darwin.nix.
  homebrew = {
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
      "raspberry-pi-imager"
      "cyberduck"
      "utm"

      # Notes
      "obsidian"

      # Messaging
      "signal"

      # Creative
      "gimp"
      "imageoptim"

      # Browsers
      "firefox"
      # "ungoogled-chromium"

      # Audio & Video Tools
      "iina"
      "xld"
      "blackhole-2ch"
      # "au-lab" # AU Lab from homebrew is intel binary, get apple silicon binary: See equaliser/au-lab/README.md
    ];

    # Applications to install from Mac App Store using mas.
    masApps = {
      # Core Tools
      "Amphetamine" = 937984704;
      "The Unarchiver" = 425424353;

      # Safari Extensions
      "Surfingkeys" = 1609752330;
      "Dark Reader for Safari" = 1438243180;

      # File Management
      "EasyFind" = 411673888;
      "LocalSend" = 1661733229;

      # Developer Tools
      "CotEditor" = 1024640650;

      # Creative
      "Pixelmator Pro" = 1289583905;

      # Maps
      "Guru Maps" = 321745474;
      # "Scenic Motorcycle Navigation" = 1089668246; # iPad/iPhone Apps not supported - https://github.com/mas-cli/mas/issues/321

      # Training
      "Tacx Training" = 892366151;

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

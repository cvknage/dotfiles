# Base system tier every NixOS machine gets.
{
  pkgs,
  user,
  owner,
  ...
}: let
  # Declare a custom XKB symbols file for a custom "U.S. English (Macintosh)" layout.
  # Use the "us(mac)" layout as a bae and swap the '`' (grave) and '§' (section) keys.
  # The intention is to make a layout that is similar to the "U.S. Internationl - PC" layout on Mac.
  # "us(mac)" used to be similar, but '`' (grave) and '§' (section) keys got swapped in a NixOS update.
  usEnglishMacintoshSymbolsFile = pkgs.writeText "us_en_macintosh" ''
    partial alphanumeric_keys
    xkb_symbols "us_en_macintosh" {
      include "us(mac)"
      key <TLDE> { [ grave, asciitilde ] };
      key <LSGT> { [ section, plusminus ] };
    };
  '';
in {
  imports = [
    # Include setup for Kanata
    ../../../../../kanata/kanata_install_nixos.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [pkgs.networkmanager-openvpn];

  # Set your time zone.
  time.timeZone = "Europe/Copenhagen";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_DK.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  # Add a custom keymap config in X11
  services.xserver.xkb = {
    layout = "us_en_macintosh";
    extraLayouts = {
      us_en_macintosh = {
        description = "U.S. English (Macintosh)";
        languages = ["eng"];
        symbolsFile = usEnglishMacintoshSymbolsFile;
      };
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Role-specific extra groups (e.g. docker) are merged in nix/contexts/<role>/system/.
  users.users.${user} = {
    isNormalUser = true;
    description = "${owner}";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Run unpatched dynamic binaries on NixOS;
  # like binaries downloaded by mason, npm, pip or vscode
  programs.nix-ld.enable = true;

  # Fuse filesystem that returns symlinks to executables based on the PATH of the requesting process.
  # This is useful to execute shebangs on NixOS that assume hard coded locations in locations like
  # /bin or /usr/bin etc.
  services.envfs.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # git # Install git here to clone dotfiles, then remove it again as git will be installed with home-manager.
    wl-clipboard # Wayland clipboard utilities
    powertop # Analyze power consumption on Intel-based laptops.
  ];

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };
}

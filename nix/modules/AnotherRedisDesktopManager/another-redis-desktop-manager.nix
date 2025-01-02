{ config, pkgs, ... }:

let

  # Set Version and SHA
  version = "1.7.1";
  SHA = "0m64isixgv6yx7h69x81nq97lx732dvvcdj1c7l9llp1qs7bir2y";

  # Build XnViewMP from AppImage
  another-redis-desktop-manager = pkgs.appimageTools.wrapType2 {
    pname = "AnotherRedisDesktopManager";
    version = "${version}";
    src = pkgs.fetchurl {
      url = "https://github.com/qishibo/AnotherRedisDesktopManager/releases/download/v${version}/Another-Redis-Desktop-Manager-linux-${version}-x86_64.AppImage";
      sha256 = "${SHA}";
    };
    extraPkgs = pkgs: with pkgs; [
      libGLU
      mesa
      xorg.libxshmfence 
    ];
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cat > $out/share/applications/another-redis-desktop-manager.desktop <<EOF
      [Desktop Entry]
      Type=Application
      Name=Another Redis Desktop Manager
      Icon=another-redis-desktop-manager
      Exec=AnotherRedisDesktopManager %F
      Categories=Graphics;
      EOF

      # Ensure the icon is copied to the right place
      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp ${icon}/share/icons/hicolor/512x512/apps/another-redis-desktop-manager.png $out/share/icons/hicolor/512x512/apps/
    '';
  };

  # Fetch and convert the icon
  icon = pkgs.runCommand "another-redis-desktop-manager-icon" { 
    nativeBuildInputs = [ pkgs.imagemagick ];
    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/qishibo/AnotherRedisDesktopManager/9cdeea3887ead462b89dfeab7a12b93c739b1c43/pack/electron/icons/icon.png";
      sha256 = "05m5wrzz7lmv75rvp8j0fmph141jp8vvvy5hqjrp1v4dpvrl6xw6";
    };
  } ''
    mkdir -p $out/share/icons/hicolor/512x512/apps
    convert $src $out/share/icons/hicolor/512x512/apps/another-redis-desktop-manager.png
  '';

in
{
  home.packages = with pkgs; [
    another-redis-desktop-manager
  ];
}


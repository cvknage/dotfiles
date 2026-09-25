# Outlook icon set for the desktop entry, window icon and tray. Sizes match what
# nixpkgs' teams-for-linux installPhase expects to find under build/icons/.
{
  fetchurl,
  imagemagick,
  lib,
  stdenv,
}: let
  # The same Wikimedia render the Firefox PWA entry pins, used as the master for
  # every size we emit.
  master = fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Microsoft_Outlook_Icon_%282025%E2%80%93present%29.svg/1280px-Microsoft_Outlook_Icon_%282025%E2%80%93present%29.svg.png";
    hash = "sha256-TJV1gOT4UFK2x6Hrpjw+GUHVjws43ndrHQqAss06rBo=";
  };

  sizes = [
    16
    24
    32
    48
    64
    96
    128
    256
    512
    1024
  ];
in
  stdenv.mkDerivation {
    pname = "outlook-for-linux-icons";
    version = "1.0";

    dontUnpack = true;

    nativeBuildInputs = [imagemagick];

    buildCommand =
      ''
        mkdir -p $out
      ''
      + lib.concatMapStrings (size: ''
        # The master render is 1280x1212, so a bare -resize would emit 512x485
        # under a 512x512 name; -extent squares the canvas with transparency.
        magick ${master} -resize ${toString size}x${toString size} -background none -gravity center -extent ${toString size}x${toString size} -strip $out/${toString size}x${toString size}.png
      '')
      sizes;

    meta = {
      description = "Outlook icon set for outlook-for-linux";
      platforms = lib.platforms.linux;
    };
  }

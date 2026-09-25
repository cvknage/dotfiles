# Outlook for Linux: upstream teams-for-linux pointed at the Outlook Web App.
{
  lib,
  pkgs,
  outlookIcons ? pkgs.callPackage ./icons.nix {},
  teamsForLinux ? pkgs.teams-for-linux,
}: let
  # Runtime code reads the FLAT option names; app/config/renames.js projects a
  # nested name onto the flat key only when the user supplied it, so these
  # defaults decide what the app loads. Each match is anchored on the option's own
  # name line, because several flat options share an identical default line.
  flat = name: default: lib.escapeShellArg "      ${name}: {\n        default: ${default},";
  # One binding per rewrite, so the pattern and the replacement cannot end up
  # naming different options: --replace-fail only proves the pattern matched.
  rename = name: from: to: "--replace-fail ${flat name from} ${flat name to}";
  str = value: ''"${value}"'';
in
  teamsForLinux.overrideAttrs (old: {
    pname = "outlook-for-linux";

    patches =
      (old.patches or [])
      ++ [
        ./patches/001-profile-dir.patch
        ./patches/002-drop-msteams-protocol.patch
        ./patches/003-tray-menu.patch
        ./patches/004-outlook-unread-badge.patch
        ./patches/005-outlook-new-mail-notifier.patch
      ];

    # nixpkgs' installPhase names everything "teams-for-linux"; that collides with a
    # co-installed Teams for Linux in home.packages.
    postInstall =
      (old.postInstall or "")
      + ''
        mv $out/bin/teams-for-linux $out/bin/outlook-for-linux
        mv $out/share/teams-for-linux $out/share/outlook-for-linux
        sed -i 's|/share/teams-for-linux/|/share/outlook-for-linux/|' $out/bin/outlook-for-linux

        # Fail here rather than at app launch if the wrapper layout changes.
        grep -q 'share/outlook-for-linux/app.asar' $out/bin/outlook-for-linux

        for icon in $out/share/icons/hicolor/*/apps/teams-for-linux.png; do
          mv "$icon" "$(dirname "$icon")/outlook-for-linux.png"
        done
      '';

    preBuild =
      (old.preBuild or "")
      + ''
        substituteInPlace app/config/options.js \
          ${rename "appIcon" (str "") (str "${outlookIcons}/512x512.png")} \
          ${rename "appTitle" (str "Microsoft Teams") (str "Microsoft Outlook")} \
          ${rename "class" "null" (str "outlook-for-linux")} \
          ${rename "onNewWindowOpenMeetupJoinUrlInApp" "true" "false"} \
          ${rename "partition" (str "persist:teams-4-linux") (str "persist:outlook-for-linux")} \
          ${rename "url" (str "https://teams.cloud.microsoft") (str "https://outlook.office.com/mail")}

        # The flat meetupJoinRegEx default is this file's, not options.js's.
        substituteInPlace app/config/defaults.js \
          --replace-fail '  meetupJoinRegEx: String.raw`^https://teams\.(?:microsoft\.com|live\.com|cloud\.microsoft)/(v2/\?meetingjoin=|meet/|l/(?:app|call|channel|chat|entity|file|meet(?:ing|up-join)|message|task|team)/)`,' \
          '  meetupJoinRegEx: String.raw`$^`,'

        # electron-builder reads the Linux icon set from build/icons.
        cp ${outlookIcons}/*.png build/icons/
      '';

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "outlook-for-linux";
        exec = "outlook-for-linux %U";
        icon = "outlook-for-linux";
        desktopName = "Outlook for Linux";
        comment = "Unofficial Microsoft Outlook client for Linux";
        categories = ["Network" "Office" "Email"];
      })
    ];

    meta =
      old.meta
      // {
        description = "Unofficial Microsoft Outlook client for Linux";
        mainProgram = "outlook-for-linux";
        platforms = lib.platforms.linux;
      };
  })

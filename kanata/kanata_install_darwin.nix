{pkgs, ...}: let
  nixAppsDirectory = "/Applications/Nix Apps";

  # Define Kanata.app for better macOS TCC (Transparency, Consent and Control) management.
  kanataVersion = pkgs.kanata.version;
  kanataIconSvg = "${pkgs.kanata}/share/icons/hicolor/scalable/apps/kanata.svg";
  kanataApp = pkgs.stdenv.mkDerivation {
    pname = "Kanata";
    version = kanataVersion;
    nativeBuildInputs = [
      pkgs.imagemagick
      pkgs.libicns
      pkgs.librsvg
    ];
    buildCommand = ''
      set -euo pipefail

      APP="$out/Kanata.app"
      ICONSET="$out/kanata.iconset"

      # ---- App Layout ----
      mkdir -p \
        "$APP/Contents/MacOS" \
        "$APP/Contents/Resources" \
        "$ICONSET"

      # ---- App Icon : SVG → PNG ----
      for size in 16 32 64 128 256 512; do
        pad=$((size * 138 / 100))
        rsvg-convert -w $size -h $size "${kanataIconSvg}" \
          | magick - -background none -gravity center \
            -extent "$pad"x"$pad" \
            -resize "$size"x"$size" \
            "$ICONSET/icon_""$size""x""$size"".png"
      done

      # ---- App Icon: PNG → ICNS ----
      png2icns "$APP/Contents/Resources/Kanata.icns" \
        "$ICONSET/icon_16x16.png" \
        "$ICONSET/icon_32x32.png" \
        "$ICONSET/icon_64x64.png" \
        "$ICONSET/icon_128x128.png" \
        "$ICONSET/icon_256x256.png" \
        "$ICONSET/icon_512x512.png"

      # ---- Info.plist ----
      cat > "$APP/Contents/Info.plist" <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
       "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleName</key>
        <string>Kanata</string>
        <key>CFBundleDisplayName</key>
        <string>Kanata</string>
        <key>CFBundleIdentifier</key>
        <string>com.jtroo.kanata</string>
        <key>CFBundleExecutable</key>
        <string>kanata-permissions</string>
        <key>LSUIElement</key>
        <true/>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>${kanataVersion}</string>
        <key>CFBundleVersion</key>
        <string>${kanataVersion}</string>
        <key>CFBundleIconFile</key>
        <string>Kanata</string>
      </dict>
      </plist>
      EOF

      # ---- Copy kanata binary ----
      cp ${pkgs.kanata}/bin/kanata \
         "$APP/Contents/MacOS/kanata"
      chmod +x "$APP/Contents/MacOS/kanata"

      # ---- Permissions dialog ----
      cat > "$APP/Contents/MacOS/kanata-permissions" <<'EOF'
      #!/usr/bin/env bash
      set -euo pipefail

      APP_NAME="kanata-permissions"
      SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

      osascript <<OSA
      display dialog "Kanata requires Input Monitoring permission to function.

      Please enable it in:
      System Settings → Privacy & Security → Input Monitoring." \
      buttons {"Open System Settings", "Quit"} \
      default button "Open System Settings" \
      with icon caution \
      with title "Kanata Permissions"

      if the button returned of the result is "Open System Settings" then
        do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent'"
      end if
      OSA
      EOF

      chmod +x "$APP/Contents/MacOS/kanata-permissions"
    '';
  };
in {
  environment.systemPackages = [
    # Install the Kanata.app
    # This is a hack that allows TCC to keep track of kanata properly so it permissions for Input Monitoring persist between updates.
    # Allow Kanata.app in macOS's TCC (Transparency, Consent and Control)
    # Under: Settings > Privacy and Security > Input Monitoring
    kanataApp

    # Symlink the kanata binary in "/run/current-system/sw/bin" folder to make the kanata command available.
    # DON'T ADD THIS TO TCC IF YOU ADDED Kanata.app - This info is only kept here in case I need it again at some point.
    # Allow kanata binary in macOS's TCC (Transparency, Consent and Control)
    # Under: Settings > Privacy and Security > Input Monitoring
    # By adding the symlink to TCC (Settings > Privacy and Security > Input Monitoring).
    # The full nix path will be added, so kanata needs to be re added for every version.
    # The kanata binary from nix will NOT be visible under Input Monitoring in the UI.
    pkgs.kanata

    # To see all kanata binaries added to TCC, run:
    /*
    sudo sqlite3 \
    "/Library/Application Support/com.apple.TCC/TCC.db" \
    "SELECT service, client FROM access WHERE client LIKE '%kanata%';"
    */

    # To remove EVERYTHING approved for Input Monitoring in TCC, run:
    /*
    sudo tccutil reset ListenEvent
    */

    # To restart the kanata daemon, run:
    /*
    launchctl kickstart -k system/com.jtroo.kanata
    */

    # To read kanata logs, run:
    /*
    sudo tail -f /Library/Logs/Kanata/kanata.out.log
    sudo tail -f /Library/Logs/Kanata/kanata.err.log
    */

    # App containing System Extension to be activated must be in "/Applications" folder.
    # This adds `.Karabiner-VirtualHIDDevice-Manager.app` to "/Applications/Nix Apps" folder so it can be activated.
    # Verify that `.Karabiner-VirtualHIDDevice-Manager` has been activated
    # Under: Settings > General > Login Items & Extensions
    pkgs.kanata.passthru.darwinDriver
  ];

  launchd.daemons.karabiner-vhidmanager = {
    script = ''
      spctl -a -vvv -t install "${nixAppsDirectory}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
      "${nixAppsDirectory}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager" activate
    '';
    serviceConfig = {
      Label = "com.pqrs-org.karabiner-vhidmanager";
      RunAtLoad = true;
    };
  };

  launchd.daemons.karabiner-vhiddaemon = {
    command = "${pkgs.kanata.passthru.darwinDriver}/Library/Application\\ Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon";
    serviceConfig = {
      Label = "com.pqrs-org.karabiner-vhiddaemon";
      ProcessType = "Interactive";
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  launchd.daemons.kanata = {
    # command = "${pkgs.kanata}/bin/kanata --cfg ${./kanata_us.kbd}";
    serviceConfig = {
      ProgramArguments = [
        "${nixAppsDirectory}/Kanata.app/Contents/MacOS/kanata"
        "--cfg"
        "${./kanata_us.kbd}"
      ];
      Label = "com.jtroo.kanata";
      ProcessType = "Interactive";
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Library/Logs/Kanata/kanata.out.log";
      StandardErrorPath = "/Library/Logs/Kanata/kanata.err.log";
    };
  };

  system.activationScripts.postActivation.text = ''
    # Update Kanata.app
    set -e
    mkdir -p "${nixAppsDirectory}"
    rm -rf "${nixAppsDirectory}/Kanata.app"
    cp -R "${kanataApp}/Kanata.app" "${nixAppsDirectory}/Kanata.app"
    chmod -R u+w "${nixAppsDirectory}/Kanata.app"

    # Restart the daemons
    launchctl kickstart -k system/com.pqrs-org.karabiner-vhiddaemon
    launchctl kickstart -k system/com.jtroo.kanata
  '';
}

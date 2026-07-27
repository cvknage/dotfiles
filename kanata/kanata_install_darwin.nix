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
      # AppleScript display dialog supports max 3 buttons, so we use a
      # two-step flow: main dialog (Help / Open Settings / Restart) and
      # a settings picker dialog if "Open Settings" is chosen.
      cat > "$APP/Contents/MacOS/kanata-permissions" <<'PERMSEOF'
      #!/usr/bin/env bash
      set -euo pipefail

      show_help() {
        osascript <<'HELP_OSA'
        display dialog ¬
          "Kanata needs macOS permissions to function:

      1. Accessibility
         System Settings → Privacy & Security → Accessibility
         • Remove any old/stale kanata entries (may show as ? icons)
         • Click + and add: /Applications/Nix Apps/Kanata.app
         • Enable the toggle

      2. Input Monitoring
         System Settings → Privacy & Security → Input Monitoring
         • Remove any old/stale kanata entries
         • Click + and add: /Applications/Nix Apps/Kanata.app
         • Enable the toggle

      3. Login Items & Extensions
         System Settings → General → Login Items & Extensions
         • Ensure Karabiner-VirtualHIDDevice-Manager is enabled

      If kanata was just upgraded, macOS pins the old binary
      path. You MUST remove stale entries and re-add Kanata.app.

      After granting permissions, click Restart Kanata." buttons {"OK"} default button "OK" with icon note with title "Kanata Permissions Help"
      HELP_OSA
      }

      show_settings() {
        CHOICE=$(osascript <<'SETTINGS_OSA'
        display dialog ¬
          "Which permission panel to open?" buttons {"Accessibility", "Input Monitoring", "Login Items"} ¬
          default button "Accessibility" with icon note ¬
          with title "Kanata — Open Settings"
        return button returned of the result
        SETTINGS_OSA
        )
        case "$CHOICE" in
          "Accessibility")
            open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
            ;;
          "Input Monitoring")
            open 'x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent'
            ;;
          "Login Items")
            open 'x-apple.systempreferences:com.apple.LoginItems-Settings.extension'
            ;;
        esac
      }

      # Main loop — re-show the dialog after opening settings
      # so the user can grant multiple permissions without relaunching.
      while true; do
        MAIN_CHOICE=$(osascript <<'MAIN_OSA'
        display dialog ¬
          "Kanata requires macOS permissions to intercept keystrokes.

      ① Accessibility — read keyboard input
      ② Input Monitoring — HID device access
      ③ Login Items & Extensions — virtual HID

      If kanata was just upgraded, remove stale entries
      and re-add Kanata.app to each permission panel." buttons {"Help", "Open Settings", "Restart Kanata"} ¬
          default button "Restart Kanata" with icon caution ¬
          with title "Kanata Permissions"

        return button returned of the result
        MAIN_OSA
        )

        case "$MAIN_CHOICE" in
          "Help")
            show_help
            ;;
          "Open Settings")
            show_settings
            ;;
          "Restart Kanata")
            osascript -e 'do shell script "launchctl kickstart -k system/com.jtroo.kanata" with administrator privileges'
            break
            ;;
        esac
      done
      PERMSEOF

      chmod +x "$APP/Contents/MacOS/kanata-permissions"
    '';
  };
in {
  environment.systemPackages = [
    # Install the Kanata.app
    # This is a hack that allows macOS TCC (Transparency, Consent and Control) to better track Input Monitoring permissions.
    # Because Kanata.app has a BundleIdentifier TCC will track it properly, unlike the kanata binary in the nix store.
    kanataApp

    # Make kanata command available.
    ## DON'T ADD THIS TO TCC, ADD Kanata.app INSTEAD - Keeping info here for reference.
    ## Allow kanata binary in macOS's TCC (Transparency, Consent and Control)
    ## Under: Settings > Privacy and Security > Input Monitoring
    ## By adding the kanata symlink "/run/current-system/sw/bin/kanata" to Input Monitoring.
    ## The symlink will evaluate to the full nix path, so it needs to be re added for every version.
    ## The kanata binary from nix will NOT be visible under Input Monitoring in the UI after you added it, though it will be added to TCC.
    pkgs.kanata

    # To see all kanata binaries added to TCC, run:
    /*
    sudo sqlite3 \
    "/Library/Application Support/com.apple.TCC/TCC.db" \
    "SELECT service, client FROM access WHERE client LIKE '%kanata%';"
    */

    # To remove stale kanata entries from TCC (needed after upgrades if
    # Accessibility/Input Monitoring is broken), do manually:
    #   1. System Settings → Privacy & Security → Accessibility → remove all kanata entries
    #   2. System Settings → Privacy & Security → Input Monitoring → remove all kanata entries
    #   3. Re-add /Applications/Nix Apps/Kanata.app to both panels
    #   4. sudo launchctl kickstart -k system/com.jtroo.kanata

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
    # Copy Kanata.app to /Applications/Nix Apps
    set -e
    mkdir -p "${nixAppsDirectory}"
    rm -rf "${nixAppsDirectory}/Kanata.app"
    cp -R "${kanataApp}/Kanata.app" "${nixAppsDirectory}/Kanata.app"
    chmod -R u+w "${nixAppsDirectory}/Kanata.app"

    # Ad-hoc codesign the kanata binary with a stable identifier.
    # macOS TCC (Accessibility/Input Monitoring) tracks binaries by code
    # signature identity. Without an explicit --identifier, ad-hoc signatures
    # change with every binary update, invalidating TCC permissions. The stable
    # identifier "com.jtroo.kanata" ensures TCC recognises the binary as the
    # same program across kanata version upgrades.
    #
    # --force: overwrite any existing signature
    # -s -:   ad-hoc sign (no keychain identity needed)
    # --identifier: stable identity string for TCC tracking
    #
    # A 10s timeout prevents the rebuild from hanging if codesign prompts
    # for keychain access. If it times out, the binary still works — TCC
    # will just need manual re-approval after kanata upgrades.
    timeout 10 codesign --force --sign - --identifier com.jtroo.kanata \
      "${nixAppsDirectory}/Kanata.app/Contents/MacOS/kanata" 2>/dev/null || true

    # Restart the daemons
    launchctl kickstart -k system/com.pqrs-org.karabiner-vhiddaemon
    launchctl kickstart -k system/com.jtroo.kanata
  '';
}

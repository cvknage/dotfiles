#!/usr/bin/env bash

# Variables
MACOS_DROVER_FOLDER="macos.driver"
KARABINER_DRIVER_NAME="Karabiner-DriverKit-VirtualHIDDevice"
KARABINER_DRIVER_FILE_NAME="${KARABINER_DRIVER_NAME}.pkg"
SUDOERS_FILE="/etc/sudoers.d/kanata"
PLIST_FILE="/Library/LaunchDaemons/com.jtroo.kanata.plist"
. ./kanata_variables.sh

# Download Karabiner Driver
mkdir -p "${MACOS_DROVER_FOLDER}"
curl -o "${MACOS_DROVER_FOLDER}/${KARABINER_DRIVER_FILE_NAME}" "$KANATA_MACOS_KARABINER_DRIVER_URI" &> /dev/null

# Install Karabiner Driver
open "${MACOS_DROVER_FOLDER}/${KARABINER_DRIVER_FILE_NAME}"

# Announce manual actions
echo ""
echo ""
echo "Install the \"${KARABINER_DRIVER_NAME}\" driver by following the installation wizard"
echo ""
echo "Run the following command to activate the \"${KARABINER_DRIVER_NAME}\" driver:"
echo "    /Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate"
echo ""
echo "Allow Kanata in macOS's TCC (Transparency, Consent and Control)"
echo "Under: Settings > Privacy and Security > Input Monitoring"
echo "Add the Kanata binary (from \"~/.cargo/bin/kanata\") to allow it to run as a launch daemon"
echo ""
echo ""

# Create a sudoers file entry for kanata
echo "$(whoami) ALL=(ALL) NOPASSWD: $KANATA_BIN_PATH" | sudo tee "$SUDOERS_FILE" > /dev/null

# Create a plist file for the LaunchDaemon
cat <<EOF | sudo tee "$PLIST_FILE" > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.jtroo.kanata</string>

    <key>ProgramArguments</key>
    <array>
        <string>$KANATA_BIN_PATH</string>
        <string>-c</string>
        <string>$KANATA_CONFIG_PATH</string>
        <string>-n</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Library/Logs/Kanata/kanata.out.log</string>

    <key>StandardErrorPath</key>
    <string>/Library/Logs/Kanata/kanata.err.log</string>
</dict>
</plist>
EOF

# Load the daemon
sudo launchctl load -w "$PLIST_FILE" 2> /dev/null

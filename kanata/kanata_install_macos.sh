#!/usr/bin/env bash

# Variables
MACOS_DRIVER_FOLDER="macos.driver"
KARABINER_DRIVER_NAME="Karabiner-DriverKit-VirtualHIDDevice"
KARABINER_DRIVER_FILE_NAME="${KARABINER_DRIVER_NAME}.pkg"
KARABINER_MANAGER_NAME=".Karabiner-VirtualHIDDevice-Manager"
KANATA_SUDOERS_FILE="/etc/sudoers.d/kanata"
KANATA_PLIST_FILE="/Library/LaunchDaemons/com.jtroo.kanata.plist"
KARABINER_DAEMON_PLIST_FILE="/Library/LaunchDaemons/com.pqrs-org.karabiner-vhiddaemon.plist"
KARABINER_MANAGER_PLIST_FILE="/Library/LaunchDaemons/com.pqrs-org.karabiner-vhidmanager.plist"
. ./kanata_variables.sh

# Download Karabiner Driver
mkdir -p "${MACOS_DRIVER_FOLDER}"
curl -o "${MACOS_DRIVER_FOLDER}/${KARABINER_DRIVER_FILE_NAME}" "$KANATA_MACOS_KARABINER_DRIVER_URI" &>/dev/null

# Install Karabiner Driver
open "${MACOS_DRIVER_FOLDER}/${KARABINER_DRIVER_FILE_NAME}"

# Announce manual actions
echo ""
echo ""
echo "Install the \"${KARABINER_DRIVER_NAME}\" driver by following the installation wizard"
echo ""
echo "Run the following command to activate the \"${KARABINER_DRIVER_NAME}\" driver:"
echo "    /Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate"
echo ""
echo "Verirify that \"${KARABINER_MANAGER_NAME}\" has been activated"
echo "Under: Settings > General > Login Items & Extensions"
echo "Check that \"${KARABINER_MANAGER_NAME}\" is listed under \"Extensions\" and that it is activated"
echo "- If it is not listed there, the \"${KARABINER_DRIVER_NAME}\" driver must be uninstalled and installed again."
echo "  It may be necessary to reboot between uninstall and install, to trigger the prompt that allows \"${KARABINER_MANAGER_NAME}\" in \"System Settings\""
echo ""
echo "Allow Kanata in macOS's TCC (Transparency, Consent and Control)"
echo "Under: Settings > Privacy and Security > Input Monitoring"
echo "Add the Kanata binary (from \"~/.cargo/bin/kanata\") to allow it to run as a launch daemon"
echo "- If this is an update from a previous version, the Kanata binary must be removed and added again"
echo ""
echo ""
read -p "Press Enter to continue..."
echo "Creating launch daemons..."

# Create a sudoers file entry for kanata
echo "$(whoami) ALL=(ALL) NOPASSWD: $KANATA_BIN_PATH" | sudo tee "$KANATA_SUDOERS_FILE" >/dev/null

# Create plist files for the LaunchDaemons
cat <<EOF | sudo tee "$KANATA_PLIST_FILE" >/dev/null
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

cat <<EOF | sudo tee "$KARABINER_DAEMON_PLIST_FILE" >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pqrs-org.karabiner-vhiddaemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

cat <<EOF | sudo tee "$KARABINER_MANAGER_PLIST_FILE" >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pqrs-org.karabiner-vhidmanager</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager</string>
        <string>activate</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load the daemons
sudo launchctl load -w "$KARABINER_MANAGER_PLIST_FILE" 2>/dev/null
sudo launchctl load -w "$KARABINER_DAEMON_PLIST_FILE" 2>/dev/null
sudo launchctl load -w "$KANATA_PLIST_FILE" 2>/dev/null

echo "Kanata is now installed and running as a launch daemon"

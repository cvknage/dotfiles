#!/usr/bin/env bash

# Variables
KANATA_PATH="$HOME/.cargo/bin/kanata"
KANATA_CFG_PATH="$HOME/.config/kanata/kanata.kbd"
SUDOERS_FILE="/etc/sudoers.d/kanata"
PLIST_FILE="/Library/LaunchDaemons/com.jtroo.kanata.plist"

# Create a sudoers file entry for kanata
echo "$(whoami) ALL=(ALL) NOPASSWD: $KANATA_PATH" | sudo tee "$SUDOERS_FILE" > /dev/null

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
        <string>$KANATA_PATH</string>
        <string>-c</string>
        <string>$KANATA_CFG_PATH</string>
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
sudo launchctl load -w "$PLIST_FILE"

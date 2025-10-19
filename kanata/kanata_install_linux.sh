#!/usr/bin/env bash

# Variables
RULES_FILE="/etc/udev/rules.d/99-input.rules"
SERVICE_FILE="$XDG_CONFIG_HOME/systemd/user/kanata.service"
. ./kanata_variables.sh

# If the uinput group does not exist, create a new group
sudo groupadd uinput

# Add your user to the input and the uinput group
sudo usermod -aG input $USER
sudo usermod -aG uinput $USER

# Make sure the uinput device file has the right permissions.
cat <<EOF | sudo tee "$RULES_FILE" >/dev/null
KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
EOF

sudo udevadm control --reload-rules && sudo udevadm trigger

# Make sure the uinput drivers are loaded
sudo modprobe uinput

# Create and enable a systemd daemon service
mkdir -p $XDG_CONFIG_HOME/systemd/user
touch "$SERVICE_FILE"

cat <<EOF | sudo tee "$SERVICE_FILE" >/dev/null
[Unit]
Description=Kanata keyboard remapper
Documentation=https://github.com/jtroo/kanata

[Service]
Environment=PATH=%h/.cargo/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin
Environment=DISPLAY=:0
Type=simple
ExecStart=/usr/bin/sh -c 'exec ${KANATA_BIN_PATH} --cfg ${KANATA_CONFIG_PATH}'
Restart=no

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable kanata.service
systemctl --user start kanata.service

# `kanata`

Configuration for [kanata](https://github.com/jtroo/kanata)

## Install

The install script will create a symlink from `$HOME/.config/kanata` to `./`:
``` bash
bash install.sh
```

## Install `kanata` binary

### Scripted Install

The scripted install will install Kanata with Cargo and set it up as system daemon

Go to the release page for [Kanata](https://github.com/jtroo/kanata/releases) and find the latest version  
Update the `./kanata_variables.sh` file with the details for the latest version

Then install it with:
``` bash
bash ./kanata_install.sh
```

### Manuan Install

Following the manual installation; you will install Kanata and install it as a system daemon

Go to the release page for [Kanata](https://github.com/jtroo/kanata/releases) and find the latest version

``` bash
git clone https://github.com/jtroo/kanata.git
```

Install Kanata with Cargo
``` bash
git checkout v<VERSION>
```

``` bash
cargo install --path <KANATA_CHECKOUT_DIR>
```

Setup host system to be ready for Kanata:
<details>
  <summary>For macOS</summary>

  Download and install the specified [`Karabiner-DriverKit-VirtualHIDDevice Driver`](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice) for the Kanata version

  To activate it:
  ``` bash
  /Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
  ```

  To uninstall it:
  ``` bash
  bash '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/deactivate_driver.sh'
  sudo bash '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/remove_files.sh'
  ```
  Allow Kanata in macOS's TCC (Transparency, Consent and Control)  
  Under: Settings > Privacy and Security > Input Monitoring  
  Add the Kanata binary (from `~/.cargo/bin/kanata`) to allow it to run as a launch daemon  

  Create a sudoers file entry for kanata
  ``` bash
  echo "$(whoami) ALL=(ALL) NOPASSWD: $KANATA_BIN_PATH" | sudo tee "$SUDOERS_FILE"
  ```

  Create a plist file for the LaunchDaemon
  ``` bash
  cat <<EOF | sudo tee "$PLIST_FILE"
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
  ```

  Load the daemon
  ``` bash
  sudo launchctl load -w "$PLIST_FILE"
  ```

  ```
  How do I use `launchctl` again?

  TL;DR

  You typically want to use launchctl load -w and launchctl unload -w.
  start and stop are usually reserved for testing or debugging a job.
  Details

  launchctl start <label>: Starts the job. This is usually reserved just for testing or debugging a particular job.
  launchctl stop <label>: Stops the job. Opposite of start, and it's possible that the job will immediately restart if the job is configured to stay running.
  launchctl remove <label>: Removes the job from launchd, but asynchronously. It will not wait for the job to actually stop before returning, so no error handling on this one.
  launchctl load <path>: Loads and starts the job as long as the job is not "disabled."
  launchctl unload <path>: Stops and unloads the job. The job will still restart on the next login/reboot.
  launchctl load -w <path>: Loads and starts the job while also marking the job as "not disabled." The job will restart on the next login/reboot.
  launchctl unload -w <path>: Stops and unloads and disables the job. The job will NOT restart on the next login/restart.
  ```
</details>

<details>
  <summary>For Gnu/Linux</summary>

  Basically follow the guide desribed [here](https://github.com/jtroo/kanata/blob/main/docs/setup-linux.md):

  If the uinput group does not exist, create a new group
  ``` bash
  sudo groupadd uinput
  ```

  Add your user to the input and the uinput group
  ``` bash
  sudo usermod -aG input $USER
  sudo usermod -aG uinput $USER
  ```

  Make sure the uinput device file has the right permissions.
  ``` bash
  cat <<EOF | sudo tee "$RULES_FILE"
  KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
  EOF
  ```

  ``` bash
  sudo udevadm control --reload-rules && sudo udevadm trigger
  ```

  Make sure the uinput drivers are loaded
  ``` bash
  sudo modprobe uinput
  ```
  Create and enable a systemd daemon service
  ``` bash
  mkdir -p ~/.config/systemd/user
  touch "$SERVICE_FILE"
  ```

  ``` bash
  cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
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
  ```

  ``` bash
  systemctl --user daemon-reload
  systemctl --user enable kanata.service
  systemctl --user start kanata.service
  ```
</details>
<br/>

On Gnu/Linux and macOS, this may not work without `sudo`
``` bash
kanata --cfg ~/.config/kanata/kanata.kbd
```

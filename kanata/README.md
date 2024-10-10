# Kanata


``` bash
git colne https://github.com/jtroo/kanata.git
```

Go to release page for [Kanata](https://github.com/jtroo/kanata/releases) and find the latest version

For macOS
Download and install the specified `Karabiner VirtualHiDDevice Driver` for the Kanata version

To activate it:
``` bash
/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
```

To uninstall it:
``` bash
bash '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/deactivate_driver.sh'
sudo bash '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/remove_files.sh'
```

Github: [Karabiner-DriverKit-VirtualHIDDevice](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice)

``` bash
git checkout v<version>
```

``` bash
cargo install --path <kanata_checkout>
```

On Linux and macOS, this may not work without `sudo`, see below
``` bash
kanata --cfg ~/.config/kanata/kanata.kbd
```

## Launch on Startup

For macOS

Allow Kanata under macOS's TCC (Transparency, Consent and Control)
Under: Settings > Privacy and Security > Input Monitoring
Add the Kanata binary (from `~/.cargo/bin/kanata`) to allow it to run as a launch daemon

Execute the LaunchDaemon installer
``` bash
bash install_launchdaemon_macos.sh

```

https://github.com/jtroo/kanata/discussions/1086
https://github.com/jtroo/kanata/issues/1211#issuecomment-2327141671

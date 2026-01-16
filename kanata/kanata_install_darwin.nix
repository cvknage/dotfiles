{pkgs, ...}: let
  nixAppsDirectory = "/Applications/Nix Apps";
in {
  environment.systemPackages = [
    # Symlink the kanata binary in "/run/current-system/sw/bin" folder.
    # Allow kanata in macOS's TCC (Transparency, Consent and Control)
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
    command = "${pkgs.kanata}/bin/kanata --cfg ${./kanata_us.kbd}";
    serviceConfig = {
      Label = "com.jtroo.kanata";
      ProcessType = "Interactive";
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Library/Logs/Kanata/kanata.out.log";
      StandardErrorPath = "/Library/Logs/Kanata/kanata.err.log";
    };
  };

  system.activationScripts.postActivation.text = ''
    launchctl kickstart -k system/com.pqrs-org.karabiner-vhiddaemon
    launchctl kickstart -k system/com.jtroo.kanata
  '';
}

# GUI applications for the linux home. On a work mac these would come from
# Homebrew instead.
{
  config,
  lib,
  pkgs,
  ...
}: let
  easyeffectsWrapped = pkgs.symlinkJoin {
    name = "easyeffects-wrapped";
    paths = [pkgs.easyeffects];
    nativeBuildInputs = [pkgs.makeWrapper];

    postBuild = ''
      gtk3Schemas="$(echo ${pkgs.gtk3}/share/gsettings-schemas/*)"
      gsdSchemas="$(echo ${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/*)"

      wrapProgram $out/bin/easyeffects \
        --prefix XDG_DATA_DIRS : "$gtk3Schemas:$gsdSchemas"
    '';
  };

  outlookForLinux = pkgs.callPackage ../../../pkgs/outlook-for-linux {};
in {
  imports = [
    # GUI applications that only make sense on a linux host; they gate their
    # own content on the platform.
    ../../../modules/home-manager/another-redis-desktop-manager
    ../../../modules/home-manager/outlook
    # ../../../modules/home-manager/claude-desktop
  ];

  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.packages = [
      pkgs.ghostty
      pkgs.slack
      pkgs.teams-for-linux
      outlookForLinux
      easyeffectsWrapped # pkgs.easyeffects

      pkgs.postman
    ];

    programs.firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };

    programs.chromium = {
      enable = true;
      package = pkgs.stable.ungoogled-chromium;
    };

    # Chromium stopped generating its own desktop icon, so add it manually
    # xdg.desktopEntries.chromium = {
    #   name = "Chromium";
    #   exec = "chromium %U";
    #   icon = "chromium";
    #   categories = ["Network" "WebBrowser"];
    # };

    # Runs as this user since the VPN's keyring secret needs this user's session.
    systemd.user.services.work-vpn-failover = let
      workVpnFailover = pkgs.writeShellApplication {
        name = "work-vpn-failover";
        runtimeInputs = [pkgs.coreutils pkgs.gawk];
        text = ''
          vpn_connection="$(cat "${config.sops.secrets.vpn_connection_name.path}")"
          trusted_wifi_connection="$(cat "${config.sops.secrets.vpn_trusted_wifi_ssid.path}")"
          vpn_up_cooldown_secs=30
          last_vpn_up_attempt=0

          # Reads an `nmcli -t -f NAME,TYPE ... ` listing from stdin.
          vpn_is_active() {
            awk -F: -v name="$vpn_connection" '$1==name && $2=="vpn" {found=1} END {exit !found}'
          }

          evaluate() {
            local active_connections now

            active_connections=$(nmcli -t -f NAME,TYPE,STATE connection show --active)

            # Matches the connection profile name, not the live SSID; safe direction if they diverge.
            if awk -F: -v name="$trusted_wifi_connection" '$1==name && $2=="802-11-wireless" {found=1} END {exit !found}' <<<"$active_connections"; then
              if vpn_is_active <<<"$active_connections"; then
                nmcli connection down "$vpn_connection" || true
              fi
              return
            fi

            if vpn_is_active <<<"$active_connections"; then
              return
            fi

            # Requires "activated", not "activating": nmcli monitor also fires on intermediate connecting states.
            if ! awk -F: '$2 != "loopback" && $2 != "vpn" && $3 == "activated" {found=1} END {exit !found}' <<<"$active_connections"; then
              return
            fi

            now=$(date +%s)
            if ((now - last_vpn_up_attempt < vpn_up_cooldown_secs)); then
              return
            fi

            # nmcli's activation can fail fast ("Could not find source connection") if the
            # route isn't installed yet, or time out while still finishing in the background --
            # poll for both instead of guessing with a fixed sleep or firing a second, overlapping
            # activation request.
            for _attempt in 1 2 3 4 5 6; do
              nmcli -t -f NAME,TYPE connection show --active | vpn_is_active && break
              if [ -n "$(ip -4 route show default)" ]; then
                nmcli -w 10 connection up "$vpn_connection" && break
              fi
              sleep 3
            done
            last_vpn_up_attempt=$(date +%s)
          }

          evaluate

          while IFS= read -r _; do
            evaluate
          done < <(nmcli monitor)
        '';
      };
    in {
      Unit = {
        Description = "Keep the work VPN up except on the trusted work wifi";
        After = ["sops-nix.service"];
        Wants = ["sops-nix.service"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${workVpnFailover}/bin/work-vpn-failover";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}

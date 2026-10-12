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
  snxRsWrapped = pkgs.callPackage ../../../pkgs/snx-rs-wrapped {};
in {
  imports = [
    # GUI applications that only make sense on a linux host; they gate their
    # own content on the platform.
    ../../../modules/home-manager/another-redis-desktop-manager
    # ../../../modules/home-manager/outlook
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

      snxRsWrapped
    ];

    sops.templates."snx-rs.conf" = {
      path = "${config.xdg.configHome}/snx-rs/snx-rs.conf";
      content = ''
        profile-name=${config.sops.placeholder.vpn_connection_name}
        server-name=${config.sops.placeholder.vpn_server_address}
        login-type=vpn_radius_login
        tunnel-type=ipsec
        user-name=${config.sops.placeholder.email}
        ca-cert=${config.sops.secrets.vpn_ca_certificate.path}
        default-route=true
        keychain=true
      '';
    };

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
  };
}

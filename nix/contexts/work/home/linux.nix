# GUI applications for the linux home. On a work mac these would come from
# Homebrew instead.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  outlookForLinux = pkgs.callPackage ../../../pkgs/outlook-for-linux {};
  snxRsWrapped = pkgs.callPackage ../../../pkgs/snx-rs-wrapped {};
  anotherRedisDesktopManager = pkgs.callPackage ../../../pkgs/another-redis-desktop-manager {};
  claudeDesktop = inputs.claude-cowork-linux.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    # Upstream pins electron_41, which nixpkgs flags insecure; the flake's own pkgs ignore our nixpkgs.config, so permit it here.
    electron_41 = pkgs.electron_41.overrideAttrs (old: {
      meta = old.meta // {knownVulnerabilities = [];};
    });
  };
in {
  imports = [
    # ../../../modules/home-manager/outlook
  ];

  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.packages = [
      pkgs.ghostty
      pkgs.easyeffects
      pkgs.postman
      pkgs.slack
      pkgs.teams-for-linux
      outlookForLinux
      anotherRedisDesktopManager
      snxRsWrapped
      claudeDesktop
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

    # claude-cowork-linux looks for the CLI only at fixed paths, never the nix profile.
    home.file.".local/bin/claude".source = "${config.programs.claude-code.package}/bin/claude";

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
  };
}

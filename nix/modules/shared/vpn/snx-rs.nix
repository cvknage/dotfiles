# nixpkgs ships snx-rs/snx-rs-gui/snxctl but no NixOS module; this unit is
# reproduced from ancwrd1/snx-rs's own package/snx-rs.service.
{pkgs, ...}: {
  systemd.services.snx-rs = {
    description = "SNX-RS VPN client";
    after = ["network.target" "network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.snx-rs}/bin/snx-rs -m command -l info";
      Restart = "on-failure";
      RestartPreventExitStatus = [1 2 255];
    };
  };
}

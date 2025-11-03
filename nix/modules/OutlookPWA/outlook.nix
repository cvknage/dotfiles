{pkgs, ...}: {
  programs.firefoxpwa = {
    enable = true;
    profiles = {
      "6E1EK5PCA97SYMR1KESJVNJ1A3" = {
        sites = {
          "3ZPKFCVA6N628YZFAFDB2MVRPN" = {
            name = "Outlook";
            url = "https://outlook.office.com/mail/";
            manifestUrl = "https://outlook.office.com/mail/manifests/pwa.json";
            desktopEntry = {
              enable = true;
              categories = ["Network" "Office" "Email"];
              icon = pkgs.fetchurl {
                url = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Microsoft_Outlook_Icon_%282025%E2%80%93present%29.svg/1280px-Microsoft_Outlook_Icon_%282025%E2%80%93present%29.svg.png";
                sha256 = "sha256-Fds4sX9TbsfRRHkHPTpqDAcNZSbYPU1XNYuU30WOttY=";
              };
            };
            settings = {
              # Not sure there settings apply correctly - but setting them in the PWA works..
              "firefoxpwa.openOutOfScopeInDefaultBrowser" = true;
              "firefoxpwa.allowedDomains" = "outlook.office.com,login.microsoftonline.com,office.com,live.com,microsoft.com";
            };
          };
        };
      };
    };
  };
}

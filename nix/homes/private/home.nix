{
  config,
  inputs,
  pkgs,
  user,
  ...
}: {
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = user;
  home.homeDirectory = "/Users/${user}";

  imports = [
    # shared between all
    ../common.nix

    # specific to home
    (
      inputs.secrets.homeManagerModules.default {
        sops-nix = inputs.sops-nix;
        keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
        secrets = {
          mutation_strings = {};
        };
      }
    )
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # Developer Tools
    pkgs.hugo
    pkgs.ollama
  ];

  programs.zsh = {
    enable = true;
    initContent = ''
      # ''${builtins.readFile ../../../shell/zsh/PS1}
      ${builtins.readFile ../../../shell/zsh/config}
      ${builtins.readFile ../../../shell/colours}
    '';
    profileExtra = ''
      ${builtins.readFile ../../../shell/common}
      if [ -f "${config.sops.secrets.mutation_strings.path}" ]; then
        export MUTATION_STRINGS="$(cat ${config.sops.secrets.mutation_strings.path})"
      fi
    '';
  };

  home.sessionVariables = {
    HOME_CONFIGUTATION_CONTEXT = "private";
  };
}

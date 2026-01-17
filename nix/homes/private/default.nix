{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
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

  home.packages = [
    # pkgs.hugo
    pkgs.ollama
  ];

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
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
    HOME_CONFIGURATION_CONTEXT = "private";
  };
}

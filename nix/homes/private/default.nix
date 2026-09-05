{
  config,
  lib,
  pkgs,
  ...
}: {
  sops.secrets = {
    mutation_strings = {};
  };

  home.packages = [
    # pkgs.hugo
    pkgs.ollama
  ];

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    completionInit = "";
    initContent = lib.mkMerge [
      # Before Home Manager's own blocks so compinit runs before fzf registers its completions.
      (lib.mkBefore ''
        ${builtins.readFile ../../../shell/zsh/config}
        ${builtins.readFile ../../../shell/colours}
      '')
      ''
        ${builtins.readFile ../../../shell/prompt}

        if prompt_is_fancy_terminal && command -v starship >/dev/null; then
          eval "$(starship init zsh)"
        else
          ${builtins.readFile ../../../shell/zsh/PS1}
        fi
      ''
    ];
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

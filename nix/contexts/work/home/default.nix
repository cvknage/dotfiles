{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./git-signing.nix
    ./linux.nix
    ./gnome.nix
    ./global-dev-tools.nix # Globally installed development tools - prefer project local tooling
  ];

  sops.secrets =
    {
      mutation_strings = {};
    }
    // inputs.nixpkgs.lib.genAttrs [
      "docker_registry_hostname"
      "github_user"
      "github_token"
      "email"
      "public_key"
    ] (_: {sopsFile = "${inputs.secrets.outPath}/secrets/homes/work/secrets.yaml";});

  home.packages = [
    pkgs.git-cliff
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      ${builtins.readFile ../../../../shell/bash/config}
      ${builtins.readFile ../../../../shell/colours}
      ${builtins.readFile ../../../../shell/prompt}

      ${builtins.readFile ../../../../shell/common}

      if prompt_is_fancy_terminal && command -v starship >/dev/null; then
        eval "$(starship init bash)"
      else
        ${builtins.readFile ../../../../shell/bash/PS1}
      fi

      export DOCKER_REGISTRY_HOSTNAME="$(cat ${config.sops.secrets.docker_registry_hostname.path})"
      export GITHUB_USER="$(cat ${config.sops.secrets.github_user.path})"
      export GITHUB_TOKEN="$(cat ${config.sops.secrets.github_token.path})"
      export GH_TOKEN="$(cat ${config.sops.secrets.github_token.path})"
      export GITHUB_REPO_PAT="$(cat ${config.sops.secrets.github_token.path})"
      export NIX_CONFIG="access-tokens = github.com/secomea-dev=$GITHUB_TOKEN"

      alias mnotes='gocryptfs ~/Notes.encrypted ~/Notes'
      alias unotes='fusermount -u ~/Notes'
    '';
    profileExtra = ''
    '';
  };

  home.sessionVariables = {
    HOME_CONFIGURATION_CONTEXT = "work";
  };
}

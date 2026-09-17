{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./git-identity.nix
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
      "github_private_key"
      "email"
      "github_public_key"
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

      export_sops_secret DOCKER_REGISTRY_HOSTNAME "${config.sops.secrets.docker_registry_hostname.path}"
      export_sops_secret GITHUB_USER "${config.sops.secrets.github_user.path}"
      export_sops_secret GITHUB_TOKEN "${config.sops.secrets.github_token.path}"
      export_sops_secret GH_TOKEN "${config.sops.secrets.github_token.path}"
      export_sops_secret GITHUB_REPO_PAT "${config.sops.secrets.github_token.path}"
      if [ -n "''${GITHUB_TOKEN-}" ]; then
        export NIX_CONFIG="access-tokens = github.com/secomea-dev=$GITHUB_TOKEN"
      fi

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

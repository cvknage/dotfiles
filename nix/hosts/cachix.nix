{ ... }:

{
  # Nix supports a variety of configuration settings, which are read from
  # configuration files or taken as command line flags.
  nix.settings = {
    extra-substituters = [
      "https://wezterm.cachix.org"
    ];

    extra-trusted-public-keys = [
      "wezterm.cachix.org-1:kAbhjYUC9qvblTE+s7S+kl5XM1zVa4skO+E/1IDWdH0="
    ];
  };
}


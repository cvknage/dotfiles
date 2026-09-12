{inputs, ...}: let
  # The flake machinery hides `nixConfig` from `inputs.self`, so re-import the file as a plain expression.
  cache = (import (inputs.self.outPath + "/flake.nix")).nixConfig;
in {
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    accept-flake-config = true;
    experimental-features = ["nix-command" "flakes"];
    extra-substituters = cache.extra-substituters;
    extra-trusted-public-keys = cache.extra-trusted-public-keys;
  };
}

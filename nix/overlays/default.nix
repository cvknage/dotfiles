{inputs, ...}: {
  stable-packages = final: prev: {
    stable = import inputs.nixpkgs-stable {system = prev.stdenv.hostPlatform.system;};

    # Compatibility aliases: some inputs still reference pkgs.hostPlatform/buildPlatform.
    hostPlatform = prev.stdenv.hostPlatform;
    buildPlatform = prev.stdenv.buildPlatform;
  };
}

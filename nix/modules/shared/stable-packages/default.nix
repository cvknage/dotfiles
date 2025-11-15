{inputs, ...}: {
  nixpkgs = {
    overlays = [
      (import ../../../overlays {inherit inputs;}).stable-packages
    ];
  };
}

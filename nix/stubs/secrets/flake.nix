{
  # Stands in for the private `secrets` input wherever it cannot be fetched. The
  # nixpkgs input exists only so `secrets.inputs.nixpkgs.follows` has a node to bind.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = {self, ...}: {};
}

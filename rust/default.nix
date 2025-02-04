{pkgs, ...}: {
  home.packages = [
    pkgs.rustup
    pkgs.cargo-generate
    pkgs.rustlings
  ];
}

{
  lib,
  pkgs,
  ...
}: {
  home.packages =
    [
      pkgs.rustup
      pkgs.cargo-generate
      pkgs.rustlings
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      pkgs.gcc # rust needs a C compiler
    ];
}

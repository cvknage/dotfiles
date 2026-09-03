# One command to apply both configuration tiers on Ubuntu, in the order they
# depend on each other: System Manager owns /etc and the system units that Home
# Manager's user environment expects to already be there.
{
  homeConfiguration,
  inputs,
  pkgs,
  system,
}:
pkgs.writeShellApplication {
  name = "ubuntu-rebuild";
  meta.description = "Apply the System Manager and Home Manager tiers on Ubuntu";
  runtimeInputs = [
    inputs.system-manager.packages.${system}.default
    inputs.home-manager.packages.${system}.default
  ];
  text = ''
    # The flake directory is a bare positional: `nix run` claims any argument
    # starting with a dash, so a `--flake` flag would need a `--` separator.
    flake="''${1:-$HOME/.dotfiles/nix}"

    if [ "$#" -gt 1 ]; then
      echo "ubuntu-rebuild: expected at most one argument" >&2
      echo "usage: ubuntu-rebuild [flake-directory]" >&2
      exit 2
    fi

    # Each tier appends its own attribute, so the path must not carry one.
    if [ "$flake" != "''${flake%#*}" ]; then
      echo "ubuntu-rebuild: pass the flake directory without an attribute, not '$flake'" >&2
      exit 2
    fi

    echo "==> System Manager: $flake#ubuntu"
    system-manager switch --flake "$flake#ubuntu" --sudo

    echo "==> Home Manager: $flake#${homeConfiguration}"
    home-manager switch --flake "$flake#${homeConfiguration}"
  '';
}

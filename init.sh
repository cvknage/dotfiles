#!/usr/bin/env bash

set -e

git config user.name "$(git log --reverse --format=%an | head -n 1)"
git config user.email "$(git log --reverse --format=%ae | head -n 1)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$HOME/.dotfiles"
if [ -L $DOTFILES_DIR ] || [ ! -d $DOTFILES_DIR ]; then
  rm $DOTFILES_DIR &>/dev/null
  ln -s $SCRIPT_DIR $DOTFILES_DIR
fi

if ! command -v nix >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    sh -s -- install

  # The determinate systems nix installer finishes with the line below:
  # To get started using Nix, open a new shell or run `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
  echo "Please open a new shell, it works better..."
  echo "Then, to continue initializing dotfiles, run \`cd ~/.dotfiles/ && bash init.sh\`"
  echo ""

  kill $(jobs -p) &>/dev/null
  exit 0
fi

pushd $DOTFILES_DIR &>/dev/null

if command -v nixos-rebuild >/dev/null; then
  OS="NixOS"
else
  OS="$(uname)"
fi
case $OS in
  "NixOS")
    sudo nixos-rebuild switch --flake ./nix
    ;;
  "Darwin")
    if ! command -v darwin-rebuild >/dev/null; then
      sudo nix run nix-darwin -- switch --flake ./nix
    else
      sudo darwin-rebuild switch --flake ./nix
    fi
    ;;
  *)
    if ! command -v home-manager >/dev/null; then
      nix run home-manager/master -- switch --flake ./nix
    else
      home-manager switch --flake ./nix
    fi
    ;;
esac

for dir in ./*/; do
  init_file="init.sh"
  if [ -f "$dir/$init_file" ]; then
    pushd "$dir" &>/dev/null
    bash "$init_file"
    popd &>/dev/null
  fi
done

if ! command -v kanata >/dev/null && $OS -ne "NixOS"; then
  pushd ./kanata &>/dev/null
  bash ./kanata_install.sh
  popd &>/dev/null
fi

popd &>/dev/null

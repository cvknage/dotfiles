#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$HOME/.dotfiles"
if [ -L $DOTFILES_DIR ] || [ ! -d $DOTFILES_DIR ]; then
  rm $DOTFILES_DIR &> /dev/null
  ln -s $SCRIPT_DIR $DOTFILES_DIR
fi

pushd $DOTFILES_DIR &> /dev/null

if ! command -v nix > /dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install
fi

OS="$(uname)"
case $OS in
"Darwin")
  if ! command -v darwin-rebuild > /dev/null; then
    nix run nix-darwin -- switch --flake ./nix
  else
    darwin-rebuild switch --flake ./nix
  fi
  ;;
*)
  if ! command -v home-manager > /dev/null; then
    nix run home-manager/master -- switch --flake ./nix
  else
    home-manager switch --flake ./nix
  fi
  ;;
esac

for dir in ./*/
do
  install_file="install.sh"
  if [ -f "$dir/$install_file" ]; then
    pushd "$dir" &> /dev/null
    bash "$install_file"
    popd &> /dev/null
  fi
done

if ! command -v kanata > /dev/null; then
  bash ./kanata/kanata_install.sh
fi

popd &> /dev/null


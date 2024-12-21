#!/usr/bin/env bash


if ! command -v nix > /dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install
fi

if ! command -v darwin-rebuild > /dev/null; then
  nix run nix-darwin -- switch --flake ./nix
fi

for dir in ./*/
do
  init_file="init.sh"
  if [ -f "$dir/$init_file" ]; then
    cd "$dir"
    bash "$init_file"
    cd ..
  fi
done


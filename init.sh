#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# One target per configuration tier, matching the sections in nix/README.md.
if [ -e /etc/NIXOS ]; then
  TARGET="nixos"
elif [ "$(uname)" = "Darwin" ]; then
  TARGET="darwin"
elif [ -r /etc/os-release ] && [ "$(. /etc/os-release && echo "$ID")" = "ubuntu" ]; then
  TARGET="ubuntu"
else
  TARGET="home-manager"
fi

# A fresh NixOS install has no git; nix-shell provides it without needing flakes.
if [ "$TARGET" = "nixos" ] && ! command -v git >/dev/null; then
  echo "Providing git from a temporary shell..."
  exec nix-shell -p git --run "bash $(printf '%q' "$SCRIPT_DIR/init.sh")"
fi

git config user.name "$(git log --reverse --format=%an | head -n 1)"
git config user.email "$(git log --reverse --format=%ae | head -n 1)"

DOTFILES_DIR="$HOME/.dotfiles"
if [ -L $DOTFILES_DIR ] || [ ! -d $DOTFILES_DIR ]; then
  rm $DOTFILES_DIR &>/dev/null
  ln -s $SCRIPT_DIR $DOTFILES_DIR
fi

# Ubuntu-owned prerequisites; must run before the Nix installer.
if [ "$TARGET" = "ubuntu" ]; then
  bash "$SCRIPT_DIR/nix/hosts/ubuntu/bootstrap.sh"
fi

if ! command -v nix >/dev/null; then
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --prefer-upstream-nix

  # The determinate systems nix installer finishes with the line below:
  # To get started using Nix, open a new shell or run `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
  echo "Please open a new shell, it works better..."
  echo "Then, to continue initializing dotfiles, run \`cd ~/.dotfiles/ && bash init.sh\`"
  echo ""

  kill $(jobs -p) &>/dev/null
  exit 0
fi

# Access to the private dotfiles-secrets input; must run before the rebuild
if ! bash "$SCRIPT_DIR/nix/secrets-bootstrap.sh"; then
  echo ""
  echo "Complete the NEXT STEPS above, then re-run \`bash init.sh\`"
  exit 0
fi

pushd $DOTFILES_DIR &>/dev/null

case $TARGET in
  nixos)
    # A fresh install has flakes disabled; enable them for this run.
    sudo nixos-rebuild switch --flake ./nix --option extra-experimental-features "nix-command flakes"
    ;;
  darwin)
    if ! command -v darwin-rebuild >/dev/null; then
      sudo nix run nix-darwin -- switch --flake ./nix
    else
      sudo darwin-rebuild switch --flake ./nix
    fi
    ;;
  ubuntu)
    nix run ./nix#ubuntu-rebuild ./nix
    ;;
  home-manager)
    if ! command -v home-manager >/dev/null; then
      nix run home-manager/master -- switch --flake "./nix#$USER@work"
    else
      home-manager switch --flake "./nix#$USER@work"
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

# Every other target installs kanata declaratively.
if [ "$TARGET" = "home-manager" ] && ! command -v kanata >/dev/null; then
  pushd ./kanata &>/dev/null
  bash ./kanata_install.sh
  popd &>/dev/null
fi

popd &>/dev/null

#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# One target per configuration tier, matching the sections in nix/README.md.
if [ -e /etc/NIXOS ]; then
  TARGET="nixos"
elif [ "$(uname)" = "Darwin" ]; then
  TARGET="darwin"
else
  DISTRO_ID=""
  [ -r /etc/os-release ] && DISTRO_ID="$(. /etc/os-release && echo "$ID")"
  case "$DISTRO_ID" in
    fedora) TARGET="$DISTRO_ID" ;;
    *) TARGET="home-manager" ;;
  esac
fi

# A fresh NixOS install has no git; nix-shell provides it without needing flakes.
if [ "$TARGET" = "nixos" ] && ! command -v git >/dev/null; then
  echo "Providing git from a temporary shell..."
  exec nix-shell -p git --run "bash $(printf '%q' "$SCRIPT_DIR/init.sh")"
fi

if [ "$(uname -s)" = "Darwin" ]; then
  if [ ! -d /Library/Developer/CommandLineTools ]; then
    xcode-select --install
    echo "Complete the Command Line Tools installation, then re-run init.sh."
    exit 0
  fi

  if [ "$(xcode-select -p)" != "/Library/Developer/CommandLineTools" ]; then
    sudo xcode-select --switch /Library/Developer/CommandLineTools
  fi
fi

git config user.name "$(git log --reverse --format=%an | head -n 1)"
git config user.email "$(git log --reverse --format=%ae | head -n 1)"

DOTFILES_DIR="$HOME/.dotfiles"
if [ -L "$DOTFILES_DIR" ] || [ ! -d "$DOTFILES_DIR" ]; then
  rm "$DOTFILES_DIR" &>/dev/null
  ln -s "$SCRIPT_DIR" "$DOTFILES_DIR"
fi

# Distro-owned prerequisites; must run before the Nix installer.
if [ -f "$SCRIPT_DIR/nix/hosts/$TARGET/bootstrap.sh" ]; then
  bash "$SCRIPT_DIR/nix/hosts/$TARGET/bootstrap.sh"
fi

if ! command -v nix >/dev/null; then
  # Where the installer ends up owning Nix, take Determinate Nix (the default)
  # for its supported upgrade path. macOS keeps upstream Nix because nix-darwin
  # manages the package itself. Fedora never reaches this: its bootstrap
  # installs Fedora's own nix package.
  case $TARGET in
    home-manager) installer_flags=() ;;
    *) installer_flags=(--prefer-upstream-nix) ;;
  esac
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install "${installer_flags[@]}"

  # The determinate systems nix installer finishes with the line below:
  # To get started using Nix, open a new shell or run `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
  echo "Please open a new shell, it works better..."
  echo "Then, to continue initializing dotfiles, run \`cd ~/.dotfiles/ && bash init.sh\`"
  echo ""

  if [ -n "$(jobs -p)" ]; then
    kill "$(jobs -p)" &>/dev/null
  fi
  exit 0
fi

# Access to the private dotfiles-secrets input; must run before the rebuild
if ! bash "$SCRIPT_DIR/nix/scripts/secrets-bootstrap.sh"; then
  echo ""
  echo "Complete the NEXT STEPS above, then re-run \`bash init.sh\`"
  exit 0
fi

pushd "$DOTFILES_DIR" &>/dev/null

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
  fedora)
    # Applies both tiers; see nix/apps/rebuild.nix
    nix run "./nix#$TARGET-rebuild"
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

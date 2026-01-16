#!/usr/bin/env bash

# Variables
KANATA_GIT_REPO="https://github.com/jtroo/kanata.git"
KANATA_GIT_CHECKOUT="kanata.git"
. ./kanata_variables.sh

function install-kanata-binary() {
  echo ""
  echo ""
  echo "Inatalling Kanata v${KANATA_VERSION}"

  if [ ! -d "${KANATA_GIT_CHECKOUT}" ]; then
    git clone "${KANATA_GIT_REPO}" "${KANATA_GIT_CHECKOUT}"
  fi
  cd "${KANATA_GIT_CHECKOUT}" && git checkout "v${KANATA_VERSION}" &>/dev/null && cd ..
  cargo install --path "./${KANATA_GIT_CHECKOUT}/" &>/dev/null
}

if command -v nixos-rebuild >/dev/null; then
  OS="NixOS"
else
  OS="$(uname)"
fi
case $OS in
  "NixOS")
    echo "To install Kanata on NixOS:"
    echo "import './kanata_install_nixos.nix' in configuration.nix"
    ;;
  "Linux")
    install-kanata-binary
    bash ./kanata_install_linux.sh
    ;;
  "Darwin")
    if command -v darwin-rebuild >/dev/null; then
      echo "Prefer to install Kanata on Darwin with nix-darwin:"
      echo "import './kanata_install_darwin.nix' in configuration.nix"
    else
      install-kanata-binary
      bash ./kanata_install_darwin.sh
    fi
    ;;
  *)
    echo "Installation of Kanata not supported for ${OS}"
    ;;
esac

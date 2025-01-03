#!/usr/bin/env bash

# Variables
KANATA_GIT_REPO="https://github.com/jtroo/kanata.git"
KANATA_GIT_CHECKOUT="kanata.git"
. ./kanata_variables.sh

echo ""
echo ""
echo "Inatalling Kanata v${KANATA_VERSION}"
if [ ! -d "${KANATA_GIT_CHECKOUT}" ]; then
  git clone "${KANATA_GIT_REPO}" "${KANATA_GIT_CHECKOUT}"
fi
cd "${KANATA_GIT_CHECKOUT}" && git checkout "v${KANATA_VERSION}" &>/dev/null && cd ..
cargo install --path "./${KANATA_GIT_CHECKOUT}/" &>/dev/null

OS="$(uname)"
case $OS in
  "Linux")
    bash ./kanata_install_linux.sh
    ;;
  "Darwin")
    bash ./kanata_install_macos.sh
    ;;
  *)
    echo "Installation of Kanata not supported for ${OS}"
    ;;
esac

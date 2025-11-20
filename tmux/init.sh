#!/usr/bin/env bash

if [ ! -d "$(pwd)/plugins" ]; then
  # Install tmux package manager
  git clone https://github.com/tmux-plugins/tpm "$(pwd)/plugins/tpm"

  # Install tmux plugins
  bash "$(pwd)/plugins/tpm/bin/install_plugins" % >/dev/null
fi

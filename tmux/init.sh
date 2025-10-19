#!/usr/bin/env bash

if [ ! -d "$(pwd)/tmux" ]; then
  # Install tmux package manager
  git clone https://github.com/tmux-plugins/tpm "$(pwd)/plugins/tpm"

  # Install tmux plugins
  bash "$XDG_CONFIG_HOME/tmux/plugins/tpm/bin/install_plugins" % >/dev/null
fi

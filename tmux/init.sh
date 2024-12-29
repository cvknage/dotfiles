#!/usr/bin/env bash

if [ ! -d "$(pwd)/tmux" ]; then
  # Install tmux package manager
  git clone https://github.com/tmux-plugins/tpm "$(pwd)/tmux/plugins/tpm"

  # Install tmux plugins
  bash "$HOME/.tmux/plugins/tpm/bin/install_plugins" %> /dev/null
fi


#!/usr/bin/env bash

# Install tmux package manager
if [ ! -d "$(pwd)/tmux" ]; then
  git clone https://github.com/tmux-plugins/tpm "$(pwd)/tmux/plugins/tpm"
fi

# Install tmux plugins
bash "$HOME/.tmux/plugins/tpm/bin/install_plugins" %> /dev/null


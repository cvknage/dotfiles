#!/usr/bin/env bash

# Symlink tmux config tile
rm -rf ~/.tmux.conf
ln -s "$(pwd)/tmux.conf" ~/.tmux.conf

# Install tmux package manager
rm -rf ~/.tmux
if [ ! -d "$(pwd)/tmux" ]; then
  git clone https://github.com/tmux-plugins/tpm "$(pwd)/tmux/plugins/tpm"
fi
ln -s "$(pwd)/tmux" ~/.tmux

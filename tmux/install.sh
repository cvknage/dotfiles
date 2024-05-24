#!/usr/bin/env bash

# Symlink tmux config tile
rm -rf ~/.tmux.conf
ln -s "$(pwd)/tmux.conf" ~/.tmux.conf

# Install tmux package manager
rm -rf ~/.tmux
rm -rf "$(pwd)/tmux"
git clone https://github.com/tmux-plugins/tpm "$(pwd)/tmux/plugins/tpm"
ln -s "$(pwd)/tmux" ~/.tmux

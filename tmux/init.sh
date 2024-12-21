#!/usr/bin/env bash

# Install tmux package manager
rm -rf ~/.tmux
rm -rf "$(pwd)/tmux"
git clone https://github.com/tmux-plugins/tpm "$(pwd)/tmux/plugins/tpm"
ln -s "$(pwd)/tmux" ~/.tmux

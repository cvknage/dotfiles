#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/nvim"

rm -rf $CONFIG_DIR
# ln -s "$(pwd)/custom" $CONFIG_DIR
ln -s "$(pwd)/lazyvim" $CONFIG_DIR

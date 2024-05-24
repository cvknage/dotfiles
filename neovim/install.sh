#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/nvim"

rm -rf $CONFIG_DIR
ln -s "$(pwd)/logic" $CONFIG_DIR

#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/ghostty"

rm -rf $CONFIG_DIR
ln -s "$(pwd)" $CONFIG_DIR

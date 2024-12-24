#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/wezterm"

rm -rf ~/.wezterm.lua # delete OLD config file location
rm -rf $CONFIG_DIR
ln -s "$(pwd)" $CONFIG_DIR

# OLD
# rm -rf ~/.wezterm.lua
# ln -s "$(pwd)/wezterm.lua" ~/.wezterm.lua

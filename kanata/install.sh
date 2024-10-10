#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/kanata"

rm -rf $CONFIG_DIR
ln -s "$(pwd)" $CONFIG_DIR

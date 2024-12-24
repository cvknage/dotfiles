#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/yazi"

rm -rf $CONFIG_DIR
ln -s "$(pwd)" $CONFIG_DIR

ya pack --install &> /dev/null

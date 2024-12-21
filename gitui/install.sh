#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/gitui"
INSTALL_DIR="$(pwd)/config/"

rm -rf $CONFIG_DIR
ln -s $INSTALL_DIR $CONFIG_DIR

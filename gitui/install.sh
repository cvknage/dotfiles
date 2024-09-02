#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/gitui"
INSTALL_DIR="$(pwd)/config/"
THEME_REPO="https://github.com/catppuccin/gitui.git"
THEME_CLONE_DIR="$(pwd)/theme/"
THEME_FILES_DIR="$THEME_CLONE_DIR/themes/"

rm -rf $CONFIG_DIR
rm -rf $INSTALL_DIR
rm -rf $THEME_CLONE_DIR

git clone $THEME_REPO $THEME_CLONE_DIR
mkdir -p $INSTALL_DIR

cp "$THEME_FILES_DIR"* $INSTALL_DIR
cp "$(pwd)/key_bindings.ron" $INSTALL_DIR

ln -s $INSTALL_DIR $CONFIG_DIR

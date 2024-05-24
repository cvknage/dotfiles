#!/usr/bin/env bash

for dir in ./*/
do
  install_file="install.sh"
  if [ -f "$dir/$install_file" ]; then
    cd "$dir"
    bash "$install_file"
    cd ..
  fi
done


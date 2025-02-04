#!/usr/bin/env bash

if command -v rustup >/dev/null; then
  # Set default rust toolchain
  rustup default stable >/dev/null
fi

#!/usr/bin/env bash

git config --global core.excludesfile "$(pwd)/.global_gitignore"

git config user.name "$(git log --format='%an' 70d261b212e4a61c2faae848511ac4532ddf580f^!)"
git config user.email "$(git log --format='%ae' 70d261b212e4a61c2faae848511ac4532ddf580f^!)"


#!/usr/bin/env bash

DOTPROFILE_FILE="$(pwd)/dotprofile"

file=""
if [ -n "$BASH_VERSION" ]; then
  file="${HOME}/.profile"
elif [ -n "$ZSH_VERSION" ]; then
  file="${HOME}/.zprofile"
fi

if [ -n "$file" ]; then
  source_file="DOTPROFILE_FILE=${DOTPROFILE_FILE}"
  comment_message='# load custom .(z)profile'
  comment_warning='(keep comment for scripted removal)'
  start_comment="${comment_message} - START - ${comment_warning}"
  load_dotrc='
if [ -f "$DOTPROFILE_FILE" ]; then
  . "$DOTPROFILE_FILE"
fi'
  end_comment="${comment_message} - END - ${comment_warning}"

  if ! grep -qF -- "$source_file" "$file"; then
    sed -i "/$start_comment/,/$end_comment/d" $file
    echo -e "$start_comment\n$source_file $load_dotrc\n$end_comment\n" >>"$file"
    . $file
  fi
fi


#!/usr/bin/env bash

: <<'EOM'
CUSTOM_DOTFILE="$(pwd)/common"
DOT_PROFILE="${HOME}/.profile"
DOT_ZPROFILE="${HOME}/.zprofile"

USER_DOTPROFILE=""
if [ -f "$DOT_ZPROFILE" ]; then
  USER_DOTPROFILE="$DOT_ZPROFILE"
elif [ -f "$DOT_PROFILE" ]; then
  USER_DOTPROFILE="$DOT_PROFILE"
fi

if [ -f "$USER_DOTPROFILE" ]; then
  SOURCE_FILE="CUSTOM_DOTFILE=${CUSTOM_DOTFILE}"
  COMMENT_MESSAGE='# load custom .(z)profile'
  COMMENT_WARNING='(keep comment for scripted removal)'
  START_COMMENT="${COMMENT_MESSAGE} - START - ${COMMENT_WARNING}"
  LOAD_DOTFILE='
if [ -f "$CUSTOM_DOTFILE" ]; then
  . "$CUSTOM_DOTFILE"
fi'
  END_COMMENT="${COMMENT_MESSAGE} - END - ${COMMENT_WARNING}"

  if ! grep -qF -- "$SOURCE_FILE" "$USER_DOTPROFILE"; then
    sed -i"" -e "/$START_COMMENT/,/$END_COMMENT/d" $USER_DOTPROFILE
    echo -e "$START_COMMENT\n$SOURCE_FILE $LOAD_DOTFILE\n$END_COMMENT\n" >>"$USER_DOTPROFILE"
    . $USER_DOTPROFILE
  fi
fi
EOM

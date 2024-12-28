{pkgs, ...}:

{
  programs.bash = {
    enable = true;
    initExtra = ''
      # PS1="\u@\h \W \$ "

      # load profile from tuxedoos
      ${builtins.readFile ./bash/bashrc}
    '';
    profileExtra = ''
      # load profile from tuxedoos
      ${builtins.readFile ./bash/profile}

      # enhance "home.sessionVariables" editor
      if command -v nvim > /dev/null; then
        alias vim=nvim
      elif command -v vim > /dev/null; then
        export EDITOR='vim'
        export VISUAL='vim'
      elif command -v vi > /dev/null; then
        export EDITOR='vi'
        export VISUAL='vi'
      elif command -v nano > /dev/null; then
        export EDITOR='nano'
        export VISUAL='nano'
      fi

      # load custom .(z)profile
      CUSTOM_DOTFILE="$HOME/.dotfiles/shell/profile"
      if [ -f "$CUSTOM_DOTFILE" ]; then
        . "$CUSTOM_DOTFILE"
      fi

      # load devbox
      if [ -f "$HOME/.devbox" ]; then
        . "$HOME/.devbox"
      fi
    '';
  };
}


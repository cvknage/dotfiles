{pkgs, ...}:

{
  programs.zsh = {
    enable = true;
    initExtra = ''
      PS1="%n@%m %1~ %# "
    '';
    profileExtra = ''
      # load custom .(z)profile
      CUSTOM_DOTFILE="$HOME/.dotfiles/shell/profile"
      if [ -f "$CUSTOM_DOTFILE" ]; then
        . "$CUSTOM_DOTFILE"
      fi
    '';
    shellAliases = {
      vim = "nvim";
    };
  };
}


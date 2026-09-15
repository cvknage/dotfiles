# Single source of truth for the repo checkout's path -- any module can ask for `dotfiles` instead of recomputing this symlink.
{config, ...}: {
  _module.args.dotfiles = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles";
}

# [neovim-config](https://neovim.io/doc/user/lua.html)

Configuration for [NeoVim](https://neovim.io) 

## Prequisites

Some of the plugins used require the following programs to function correctly:

- [luarocks](https://github.com/luarocks/luarocks)  
**[MacPorts]()**: `sudo port lua-luarocks`  
**[Homebrew]()**: `brew install luarocks`  
**[Apt]()**: `sudo apt install luarocks`  

- [ripgrep](https://github.com/BurntSushi/ripgrep)  
**[MacPorts](https://ports.macports.org/port/ripgrep/)**: `sudo port install ripgrep`  
**[Homebrew](https://formulae.brew.sh/formula/ripgrep)**: `brew install ripgrep`  
**[Apt](https://packages.debian.org/sid/ripgrep)**: `sudo apt install ripgrep`  

- [fd](https://github.com/sharkdp/fd)  
**[MacPorts](https://ports.macports.org/port/fd/)**: `sudo port install fd`  
**[Homebrew](https://formulae.brew.sh/formula/fd)**: `brew install fd`  
**[Apt](https://packages.debian.org/sid/fd-find)**: `sudo apt install fd-find`  

- [sed](https://www.gnu.org/software/sed/)  
**[MacPorts](https://ports.macports.org/port/gsed/)**: `sudo port install gsed`  
**[Homebrew](https://formulae.brew.sh/formula/gnu-sed)**: `brew install gnu-sed`  
**[Apt](https://packages.debian.org/sid/sed)**: `sudo apt install sed`  

### Optional

- [fzf](https://github.com/junegunn/fzf)  
**[MacPorts]()**: `sudo port install fzf`  
**[Homebrew]()**: `brew install fzf`  
**[Apt]()**: `sudo apt install fzf`  

- [jq](https://jqlang.github.io/jq/)  
**[MacPorts]()**: `sudo port install jq`  
**[Homebrew]()**: `brew install jq`  
**[Apt]()**: `sudo apt install jq`  

## Install

The install script will create a symlink from `$HOME/.config/nvim` to `./logic`:
``` bash
bash install.sh
```


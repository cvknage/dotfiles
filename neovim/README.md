# `nvim`

Configuration for [neovim](https://neovim.io) 

-- [neovim Lua-guide](https://neovim.io/doc/user/lua-guide.html)  
-- [neovim Lua](https://neovim.io/doc/user/lua.html)  
-- [Learn Neovim](https://ofirgall.github.io/learn-nvim/)  
-- [Learn Vimscript the Hard Way](https://learnvimscriptthehardway.stevelosh.com)  

## Prequisites

Some of the plugins used require the following programs to function correctly:

- [luarocks](https://github.com/luarocks/luarocks)  
**[MacPorts](https://ports.macports.org/port/lua-luarocks/)**: `sudo port install lua-luarocks`  
**[Homebrew](https://formulae.brew.sh/formula/luarocks)**: `brew install luarocks`  
**[Apt](https://packages.debian.org/sid/luarocks)**: `sudo apt install luarocks`  

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
**[MacPorts](https://ports.macports.org/port/fzf/)**: `sudo port install fzf`  
**[Homebrew](https://formulae.brew.sh/formula/fzf)**: `brew install fzf`  
**[Apt](https://packages.debian.org/sid/fzf)**: `sudo apt install fzf`  

- [jq](https://jqlang.github.io/jq/)  
**[MacPorts](https://ports.macports.org/port/jq/)**: `sudo port install jq`  
**[Homebrew](https://formulae.brew.sh/formula/jq)**: `brew install jq`  
**[Apt](https://packages.debian.org/sid/jq)**: `sudo apt install jq`  

## Install

The install script will create a symlink from `$HOME/.config/nvim` to `./logic`:
``` bash
bash install.sh
```


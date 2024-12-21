# `nix`

Configuration for [`nix`](https://nixos.org/learn/)

## Install

Install Nix with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)

On MacOS; bootstrap [`nix-darwin`](https://github.com/LnL7/nix-darwin) with the following command:
``` bash
nix run nix-darwin -- switch --flake .
```

On Gnu/Linux (Not NixOS); bootstrap [`home-manager`](https://github.com/nix-community/home-manager) with the following command:
``` bash
nix run home-manager/master -- switch --flake .
```

## Usage

Update the configuration, and build a new version.

On MacOS:
``` bash
darwin-rebuild switch --flake .
```

On Gnu/Linux (Not NixOS):
``` bash
home-manager switch --flake .
```

### Search for packages

As specified in the [documentation](https://nixos.wiki/wiki/Searching_packages):  
The easiest way to search for packages is to use the [search.nixos.org website](https://search.nixos.org/packages)  
Or use this command: `nix search nixpkgs firefox`  

However I often find it easier to search for packages on this [3'rd party website](https://searchix.alanpearce.eu/all/search)

### Clean store

Use the command [`nix-collect-garbage`](https://nix.dev/manual/nix/2.24/command-ref/nix-collect-garbage.html) to delete unreachable store objects


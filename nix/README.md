# `nix`

Configuration for [`nix`](https://nixos.org/learn/)  
Unofficial [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/introduction/)

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
Or use this command: 
``` bash
nix search nixpkgs firefox
```

However I often find it easier to search for packages on this [3'rd party website](https://searchix.alanpearce.eu/all/search)

### Update

With Flakes, updating the system is straightforward. Simply execute the following commands.

#### Update flake.lock
``` bash
nix flake update --flake .
```

#### Or replace only the specific input, such as home-manager:
``` bash
nix flake update home-manager --flake .
```

Then apply the updates.

### Clean store

Use the command [`nix-collect-garbage`](https://nix.dev/manual/nix/2.24/command-ref/nix-collect-garbage.html) to delete unreachable store objects
``` bash
nix-collect-garbage
```


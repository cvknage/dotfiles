# `nix`

Configuration for [`nix`](https://nixos.org/learn/)

## Install

Install Nix with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)

On MacOS; bootstrap [`nix-darwin`](https://github.com/LnL7/nix-darwin) with the following command:
``` bash
nix run nix-darwin -- switch --flake .
```

On Gnu/Linux (Not NixOS); bootstrap `home-manager` with the following command:
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

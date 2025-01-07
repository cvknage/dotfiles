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

### Install old versions of packages

To install an old version of a package, the easiest way may be to add the `nixpkgs` channel that contains the version you want to the inputs in the flake like this:
``` bash
nixpkgs-22-11.url = "nixpkgs/release-22.11";
```
or add a specific `nixpkgs` reference from a commit on `https://github.com/NixOS/nixpkgs`, that containt the version yuo want, like this:
``` bash
nixpkgs_tmux33a.url = "github:NixOS/nixpkgs/10b813040df67c4039086db0f6eaf65c536886c6";
```

Then use the input when installing a package like this:
``` bash
home.packages = [
  inputs.nixpkgs_tmux33a.legacyPackages.${pkgs.system}.tmux
];
```

Finding the git commit hash for a specific `nixpkgs`, can be done by searching for the package you want on one of there sites:
- [Nixhub](https://www.nixhub.io/)  
- [Nix package versions](https://lazamar.co.uk/nix-versions/)  

### Clean store

Use the command [`nix-collect-garbage`](https://nix.dev/manual/nix/2.24/command-ref/nix-collect-garbage.html) to delete unreachable store objects
``` bash
nix-collect-garbage
```
## Uninstall

On MacOS; [`nix-darwin`](https://github.com/LnL7/nix-darwin/blob/master/README.md#uninstalling) [**MUST be uninstalled before removing `nix`**](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#using-macos-after-removing-nix-while-nix-darwin-was-still-installed-network-requests-fail) with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#uninstalling)
``` bash
nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller
```
``` bash
/nix/nix-installer uninstall
```

On Gnu/Linux (Not NixOS); uninstall `nix` with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#uninstalling)
``` bash
/nix/nix-installer uninstall
```


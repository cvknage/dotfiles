# `nix`

Configuration for [`nix`](https://nixos.org/learn/)  


- [Nix Reference Manual](https://nix.dev/manual/nix/rolling)
- [Nixpkgs Reference Manual](https://nixos.org/manual/nixpkgs/unstable/)
- [NixOS Manual](https://nixos.org/manual/nixos/unstable/)
- Unofficial - [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/introduction/)

## Install

Install Nix with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer).

**macOS:** bootstrap [`nix-darwin`](https://github.com/LnL7/nix-darwin) with:

```bash
nix run nix-darwin -- switch --flake .
```

**GNU/Linux (not NixOS):** bootstrap [`home-manager`](https://github.com/nix-community/home-manager) with:

```bash
nix run home-manager/master -- switch --flake .
```

## Usage

Update the configuration and rebuild the system.

**macOS:**

```bash
sudo darwin-rebuild switch --flake .
```

**GNU/Linux (not NixOS):**

```bash
home-manager switch --flake .
```

**NixOS:**

```bash
sudo nixos-rebuild switch --flake .
```

### Search for packages

- nixpkgs: [NixOS Search - Packages](https://search.nixos.org/packages)  
    - Command line: `nix search nixpkgs <PACKAGE>`  
- NixOS options: [NixOS Search - Options](https://search.nixos.org/options)  
- Home Manager options: [Home Manager Options Search](https://home-manager-options.extranix.com/)  

Alternatively; use [Searchix](https://searchix.alanpearce.eu/all/search) for all your package needs

### Update Flakes

Update `flake.lock`:

```bash
nix flake update --flake .
```

Update a specific input (e.g., Home Manager):

```bash
nix flake update home-manager --flake .
```

Then rebuild the system.

### Install old versions of packages

Add a channel or commit reference in your flake inputs:

```bash
nixpkgs_2211.url = "nixpkgs/release-22.11";
nixpkgs_tmux33a.url = "github:NixOS/nixpkgs/10b813040df67c4039086db0f6eaf65c536886c6";
```

Use the input when installing a package:

```bash
home.packages = [
  inputs.nixpkgs_2211.legacyPackages.${pkgs.system}.git
  inputs.nixpkgs_tmux33a.legacyPackages.${pkgs.system}.tmux
];
```

Find the git commit hash for a specific `nixpkgs`, by searching for the desired package on one of there sites:
- [Nixhub](https://www.nixhub.io/)  
- [Nix package versions](https://lazamar.co.uk/nix-versions/)  

### Generations Explained

Nix keeps **system and user generations** as snapshots of the system or profile state. This affects cleaning and garbage collection.

- **System generations**:  
  Created by `nixos-rebuild switch` or `darwin-rebuild switch`. Stored under `/nix/var/nix/profiles/system`. Includes the system state and, if Home Manager is used as a module, also Home Manager state.

- **User generations**:  
  Created by `nix-env` or standalone Home Manager (`home-manager switch`). Stored under `/nix/var/nix/profiles/per-user/$USER/`. These only affect the user’s profile and packages.

- **Home Manager generations**:  
  - **Module mode**: Included in system generations. No separate cleanup required.  
  - **Standalone mode**: Maintains its own generations under `/nix/var/nix/profiles/per-user/$USER/home-manager`. Needs user-level cleanup.

### Clean store and generations

Nix stores all packages and build outputs in `/nix/store`. Old system states (“generations”) keep store paths alive until deleted. Cleaning involves:

1. Removing old generations
2. Running garbage collection

#### Clean store only

To remove unreferenced store paths:

```bash
nix-collect-garbage
```

#### Clean generations and free disk space

**NixOS**

List system generations:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Delete older generations while keeping the last 3:

```bash
sudo nix-env --delete-generations --profile /nix/var/nix/profiles/system +3
```

Run garbage collection:

```bash
sudo nix-collect-garbage
```

Rebuild the boot menu:

```bash
sudo nixos-rebuild switch --flake .
```

> Avoid `sudo nix-collect-garbage -d` if you want to keep the last 3 generations. That deletes all old generations.

**macOS (nix-darwin)**

List generations:

```bash
sudo darwin-rebuild --list-generations
```

Delete older generations while keeping the last 3:

```bash
sudo darwin-rebuild switch --delete-generations +3
```

Run garbage collection:

```bash
sudo nix-collect-garbage
```

> `nix-collect-garbage -d` without `sudo` only affects your user profile.

#### Home Manager

**Module mode (NixOS / macOS)**

- State is included in system generations.
- Cleanup happens with system GC (`sudo nix-collect-garbage`).

**Standalone mode**

Profile at `/nix/var/nix/profiles/per-user/$USER/home-manager`

List generations:

```bash
home-manager generations
```

Delete old generations:

```bash
nix-collect-garbage
```

> `sudo` is not needed in standalone mode.

## Uninstall

**macOS:**  
[`nix-darwin`](https://github.com/LnL7/nix-darwin/blob/master/README.md#uninstalling) [**MUST be uninstalled before removing `nix`**](https://github.com/DeterminateSystems/nix-installer/blob/main/docs/quirks.md#using-macos-after-removing-nix-while-nix-darwin-was-still-installed-network-requests-fail) with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#uninstalling)
``` bash
nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller
```
``` bash
/nix/nix-installer uninstall
```

**GNU/Linux (not NixOS):**  
Uninstall `nix` with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#uninstalling)
```bash
/nix/nix-installer uninstall
```


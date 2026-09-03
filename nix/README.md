# `nix`

Configuration for [`nix`](https://nixos.org/learn/)  


- [Nix Reference Manual](https://nix.dev/manual/nix/rolling)
- [Nixpkgs Reference Manual](https://nixos.org/manual/nixpkgs/unstable/)
- [NixOS Manual](https://nixos.org/manual/nixos/unstable/)
- Unofficial - [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/introduction/)

## Install

Install Nix with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer).

Then run `bash init.sh` from the repo root, which also bootstraps the secrets key (see [Secrets](#secrets)).  
Or follow the manual steps below:

**NixOS:** bootstrap [`nixos-rebuild`](https://nixos.org/manual/nixos/unstable/#sec-changing-config) with:

```bash
nix-shell -p git
sudo nixos-rebuild switch --flake . --option extra-experimental-features "nix-command flakes"
```

> A fresh install has neither `git` nor flakes, so both are supplied for this one run. Clone this repo from the
> shell; afterwards they come from this configuration.

**macOS:** bootstrap [`nix-darwin`](https://github.com/LnL7/nix-darwin) with:

```bash
nix run nix-darwin -- switch --flake .
```

**Ubuntu:** bootstrap [`system-manager`](https://github.com/numtide/system-manager) with:

```bash
bash nix/hosts/ubuntu/bootstrap.sh
nix run ./nix#ubuntu-rebuild ./nix
```

`ubuntu-rebuild` applies `system-manager` for the system tier, then `home-manager` for the user environment.

Ubuntu stays authoritative for boot, drivers, GNOME, networking, and Docker. `bootstrap.sh` prints the driver,
endpoint-security, and IdM steps it leaves to Ubuntu.

On first apply:

- `sudo systemctl restart docker` to pick up the agent-boundary drop-ins.
- Log out and back in for the `docker`, `input`, and `uinput` groups, and so the desktop picks up `XDG_DATA_DIRS`.
- Pick "GNOME" rather than "Ubuntu" at the login screen. `bootstrap.sh` installs the upstream session, which is
  what the managed dconf settings and GNOME extensions target. If the option is missing, `/usr/share/wayland-sessions/`
  has no `gnome.desktop`; install `vanilla-gnome-desktop` with `--no-install-recommends` instead.
- On X11, copy `xkb/us_en_macintosh` into `/usr/share/X11/xkb/symbols/` — only Wayland reads the copy Home Manager
  writes to `~/.config/xkb/symbols`.

**Fedora:** bootstrap [`system-manager`](https://github.com/numtide/system-manager) with:

```bash
bash nix/hosts/fedora/bootstrap.sh
nix run ./nix#fedora-rebuild ./nix
```

> Experimental. `bootstrap.sh` installs Fedora's own `nix` package rather than using the Determinate installer:
> Fedora 44 ships 2.34.8, the version the flake already pins, built against Fedora's SELinux policy. That should
> avoid the denials that stop systemd running `/nix/store` binaries, but it is untested here — the checks below
> settle it. Also sets `system-manager.allowAnyDistro`, and needs no GNOME session package.

### Verifying a rebuild

Both tiers fail quietly in places. Run these after `ubuntu-rebuild` or `fedora-rebuild`.

Ubuntu and Fedora both:

```bash
readlink /run/opengl-driver                                  # a /nix/store path, not empty
systemctl cat docker | grep agent-boundary                   # drop-in loaded
systemctl show docker -p ProtectHome                         # ProtectHome=tmpfs, so it took effect
systemctl status uinput-setup kanata                         # both active
command -v kanata                                            # under /run/system-manager/sw/bin
systemctl --user show-environment | grep XDG_DATA_DIRS       # includes ~/.nix-profile/share
systemctl --user status sops-nix git-signing-agent-relay     # both active; secrets render here
ls /etc/claude-code/managed-settings.json /etc/codex/requirements.toml
```

Ubuntu only:

```bash
ls /usr/share/wayland-sessions/                              # gnome.desktop, for the upstream session
sudo ufw status                                              # if active, 53317 open for localsend
```

Fedora only:

```bash
sudo ausearch -m avc -ts recent                              # no output
sudo firewall-cmd --list-ports                               # 53317/tcp and 53317/udp for localsend
```

> Denials naming `/nix/store` or `default_t` are the known Fedora problem: systemd refusing to run services from the
> store. The two `--user` services above are the canary.

**Home Manager:** bootstrap [`home-manager`](https://github.com/nix-community/home-manager) with:

```bash
nix run home-manager/master -- switch --flake '.#ckn@work'
sudo nix run ./nix#install-agent-policy
```

> Standalone Home Manager has no system tier, so re-run `install-agent-policy` after every switch, and run the
> `sudo non-nixos-gpu-setup` command it prints so GPU-accelerated apps have drivers. Ubuntu does both for you.

## Secrets

Secrets live in the private [cvknage/dotfiles-secrets](https://github.com/cvknage/dotfiles-secrets) repo,
encrypted with [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).

Each machine has one keypair, `~/.ssh/keys/dotfiles-secrets`:

> The key lives in a subdirectory because GNOME's gcr ssh-agent auto-loads
> `~/.ssh/*.pub` keys into the agent, where libgit2 clients (gitui) offer the
> deploy key to GitHub first and get "Repository not found" on other repos.

- **GitHub deploy key** — read-only access to the secrets repo
- **sops age identity** — converted by sops-nix at activation (`sops.age.sshKeyPaths`)

The flake input is fetched via the `github-secrets` ssh alias: github.com,
offering only this keypair. It is defined once in `modules/shared/secrets-ssh-alias.nix`
and rendered into `/etc/ssh` (system configs) and `~/.ssh/config` (standalone home-manager).
`secrets-bootstrap.sh` creates the keypair and primes the input for the first rebuild.

### New machine

```bash
bash init.sh
```

Follow the printed instructions:

1. Add the deploy key on GitHub
2. From an existing machine: add the age recipient to `.sops.yaml` and run
   `sops updatekeys` on the files the new machine should read

### Retiring a machine

1. Delete its [deploy key](https://github.com/cvknage/dotfiles-secrets/settings/keys)
2. Remove its recipient from `.sops.yaml` and re-run `sops updatekeys`
3. Rotate any secrets it could read

### Without a key

Homes that don't import `homes/shared/secrets.nix` build without a key — flake
inputs are fetched lazily. `nix flake update` needs repo access; update named
inputs instead: `nix flake update nixpkgs --flake .`

## Usage

Update the configuration and rebuild the system.

**NixOS:**

```bash
sudo nixos-rebuild switch --flake .
```

**macOS:**

```bash
sudo darwin-rebuild switch --flake .
```

**Ubuntu / Fedora:**

```bash
nix run ./nix#ubuntu-rebuild ./nix
nix run ./nix#fedora-rebuild ./nix
```

**Home Manager:**

```bash
home-manager switch --flake '.#ckn@work'
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

### Updating Nix itself

`nix flake update` moves nixpkgs, not the Nix binary. Which tier owns Nix differs:

- **NixOS and macOS:** the flake, so `nix flake update nixpkgs` and a rebuild. `nix.enable = true` puts
  `nix.package` under the flake's control.
- **Fedora:** `dnf`. Nix comes from Fedora's repos, so `dnf upgrade` moves it with the rest of the system.
- **Ubuntu and standalone Home Manager:** the Determinate installer, so `sudo determinate-nixd upgrade`. Neither tier
  can own the Nix package — System Manager's `nix` module writes `nix.conf` and nothing else.

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

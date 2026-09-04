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

**Fedora:** bootstrap [`system-manager`](https://github.com/numtide/system-manager) with:

```bash
bash nix/hosts/fedora/bootstrap.sh
nix run ./nix#fedora-rebuild ./nix
```

`fedora-rebuild` applies `system-manager` for the system tier, then `home-manager` for the user environment.

Fedora stays authoritative for the kernel, drivers, desktop, identity, and Docker. `bootstrap.sh` prints the
endpoint-security, SELinux, firewall, and IdM enrollment steps it leaves to Fedora.

> Experimental: System Manager only asserts support for `nixos`, `ubuntu`, and `debian`, so this host sets
> `system-manager.allowAnyDistro`. `bootstrap.sh` installs Fedora's own `nix` package rather than the Determinate
> installer, but that alone doesn't stop systemd (`init_t`) from being denied
> access to `/nix/store` binaries — so it also labels the whole store `bin_t`, and `fedora-rebuild` relabels each
> new generation's closure before System Manager activates it.

On first apply:

- Log out and back in (or reboot) for the `docker`, `input`, and `uinput` groups.
- If `akmod-nvidia` was installed, reboot — the driver builds on first boot, and Secure Boot needs the MOK
  enrollment screen confirmed (the menu is QWERTY).

**Home Manager:** bootstrap [`home-manager`](https://github.com/nix-community/home-manager) with:

```bash
nix run home-manager/master -- switch --flake '.#ckn@work'
sudo nix run ./nix#install-agent-policy
```

> Standalone Home Manager has no system tier, so re-run `install-agent-policy` after every switch, and run the
> `sudo non-nixos-gpu-setup` command it prints so GPU-accelerated apps have drivers. A System Manager host (e.g.
> Fedora) does both for you.

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
offering only this keypair. It is defined once in `modules/shared/secrets/alias.nix`
and rendered into `/etc/ssh` (system configs) and `~/.ssh/config` (standalone home-manager).
`scripts/secrets-bootstrap.sh` creates the keypair and primes the input for the first rebuild.

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

Homes that do not import `modules/home/secrets` build without a key — flake
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

**Fedora:**

```bash
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
- **Standalone Home Manager:** the Determinate installer, so `sudo determinate-nixd upgrade`. It can't own the Nix
  package itself — System Manager's `nix` module writes `nix.conf` and nothing else.

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

### Generations and garbage collection

Each rebuild keeps the previous generation as a GC root, so old store paths stick around until it's deleted. Delete
generations first, then collect.

- **NixOS / macOS:** one system profile, `/nix/var/nix/profiles/system`. Home Manager as a module rides along in it.
- **System Manager hosts (e.g. Fedora):** two independent profiles — System Manager's,
  `/nix/var/nix/profiles/system-manager-profiles/system-manager`, and standalone Home Manager's,
  `~/.local/state/nix/profiles/home-manager`.
- **Standalone Home Manager** (no system tier): just the Home Manager profile above.

**NixOS**

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nix-env --delete-generations --profile /nix/var/nix/profiles/system +3
sudo nix-collect-garbage
sudo nixos-rebuild switch --flake .   # rebuild the boot menu
```

> The last command isn't optional: the boot menu still lists deleted generations until it runs, and selecting one
> of those entries fails to boot since their store paths are gone.
>
> `nix-collect-garbage -d` deletes *all* old generations, not just the unreferenced store paths.

**macOS (nix-darwin)**

```bash
sudo darwin-rebuild --list-generations
sudo darwin-rebuild switch --delete-generations +3
sudo nix-collect-garbage
```

**System Manager**

`system-manager` has no `--list-generations` of its own; manage its profile directly:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system-manager-profiles/system-manager
sudo nix-env --delete-generations --profile /nix/var/nix/profiles/system-manager-profiles/system-manager +3
```

Then clean the standalone Home Manager profile:

```bash
home-manager generations
home-manager remove-generations <id>...
```

Both share the same store, so one collection covers them:

```bash
sudo nix-collect-garbage
```

**Standalone Home Manager (no system tier)**

```bash
home-manager generations
home-manager remove-generations <id>...
nix-collect-garbage   # no sudo -- user profile only
```

### Roll back a generation

**NixOS / macOS** have a dedicated flag:

```bash
sudo nixos-rebuild switch --rollback   # NixOS
sudo darwin-rebuild --rollback         # macOS
```

**System Manager and standalone Home Manager** don't — switch the profile, then run that
generation's own activation script (each generation carries one):

```bash
sudo nix-env --switch-generation <N> --profile /nix/var/nix/profiles/system-manager-profiles/system-manager
sudo /nix/var/nix/profiles/system-manager-profiles/system-manager/bin/activate
```

```bash
nix-env --switch-generation <N> --profile ~/.local/state/nix/profiles/home-manager
~/.local/state/nix/profiles/home-manager/activate
```

## Uninstall

**macOS:**  
[`nix-darwin`](https://github.com/LnL7/nix-darwin/blob/master/README.md#uninstalling) [**MUST be uninstalled before removing `nix`**](https://github.com/DeterminateSystems/nix-installer/blob/main/docs/quirks.md#using-macos-after-removing-nix-while-nix-darwin-was-still-installed-network-requests-fail),
via the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#uninstalling):

```bash
nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller
/nix/nix-installer uninstall
```

**System Manager hosts (e.g. Fedora):**  
Deactivate `system-manager` first, same reasoning as `nix-darwin` above — it leaves managed config pointing at a
store that's about to disappear:

```bash
nix run github:numtide/system-manager -- deactivate --sudo
```

Then remove `nix` itself, however that host's tier owns it (see "Updating Nix itself" above). Fedora's is a plain
`dnf` package, not the Determinate installer:

```bash
sudo systemctl disable --now nix-daemon
sudo dnf remove nix nix-daemon
```

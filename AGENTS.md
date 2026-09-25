# `.dotfiles` Agent Guide

> Repo-scoped instructions for anyone automating or editing this configuration. Global guardrails still live in
> `agents/AGENTS.md`.

## 0. Mental Model
1. This repository is the single source of truth for macOS (nix-darwin), NixOS, Fedora (System Manager +
   standalone Home Manager), and standalone Home Manager environments.
2. Everything is orchestrated through the flake in `nix/`; resist ad-hoc OS/package changes.
3. Secrets are delivered via `sops-nix` + the `secrets` flake input—never open decrypted payloads, only reference the managed paths.

## 1. Getting Set Up
- Run `bash init.sh` once after cloning; it links `~/.dotfiles`, installs Nix if needed, then performs the appropriate rebuild (`darwin-rebuild`, `nixos-rebuild`, or `home-manager switch`).
- MCP servers (NixOS, Context7, etc.) are configured in `nix/modules/home-manager/agents/mcp`; prefer using them whenever applicable.

## 2. Command Reference (Build/Lint/Test)
- **Flake validation:** `nix flake check ./nix` — evaluates recognized outputs and runs checks for the current system.
- **NixOS target:** `nix build ./nix#nixosConfigurations.penguin-tuxedo.config.system.build.toplevel`.
- **macOS target:** `nix build ./nix#darwinConfigurations.logic.system`.
- **Home Manager target:** `nix build './nix#homeConfigurations."ckn@work".activationPackage'`.
- **System Manager target:** `nix build ./nix#linuxConfigurations.ckn-laptop.system`.
- **macOS rebuild:** `sudo darwin-rebuild switch --flake ./nix` (automatically manages Homebrew through `nix-homebrew`).
- **NixOS rebuild:** `sudo nixos-rebuild switch --flake ./nix` (pulls in shared + host-specific modules).
- **Standalone Home Manager:** `home-manager switch --flake './nix#ckn@work'` — one configuration for every
  standalone Linux work host, regardless of hostname or distro.
- **Fedora rebuild:** `nix run ./nix#linux-rebuild -- switch --flake ./nix` — the generic System Manager rebuild
  app; takes an action (`switch` or `build`) and points at the machine through the flake ref
  (`--flake ./nix#ckn-laptop`, or bare `./nix` for the box's own hostname; machine keys come from
  `linuxConfigurations` in `nix/flake.nix`). Always runs against `~/.dotfiles/nix`; implemented in
  `nix/apps/rebuild.nix`. Individual tier: `nix run github:numtide/system-manager -- switch --flake ./nix#ckn-laptop --sudo`.
- The rebuild app also applies the Home Manager tier, which installs a `<distro>-rebuild` convenience package
  (e.g. `fedora-rebuild`, via `nix/lib/mk-generic-linux-system.nix`) for later runs.
- **Distro prerequisites:** `bash nix/contexts/shared/system/fedora/bootstrap.sh` installs the distro-owned packages the Nix tiers
  depend on. Idempotent, and elevates only when something is missing.
- **Fedora is experimental:** System Manager only asserts support for ubuntu and debian, so
  `nix/contexts/shared/system/fedora/default.nix` sets `system-manager.allowAnyDistro`.
- **Standalone agent policy:** after every standalone Home Manager switch, run
  `sudo nix run ./nix#install-agent-policy`. Not needed where a system tier exists, which owns the
  `/etc` policy via its platform agents module (`nix/modules/{nixos,darwin,system-manager}/agents`).
- **Format Nix:** `(cd nix && nix fmt -- .)` — Alejandra via the flake's `formatter` output. `nix fmt` resolves the
  formatter from the *current* directory's flake, not from its argument, so it must run inside `nix/`; from the repo
  root it fails with "is not part of a flake". For single files: `alejandra path/to/file.nix` if available.
- **Lua formatting:** `cd neovim && stylua .` (configs expect 2 spaces / 120 cols; formatting on save is normally enabled).
- **Shell linting:** use `bash -n script.sh` for syntax checks and `shellcheck script.sh` (install via Nix if missing) before committing substantive shell changes.

## 3. Repo Map & Ownership
- `nix/` — flakes, overlays, modules, and the configuration axes: `nix/hardware/<machine>` (hardware only) and
  `nix/contexts/{shared,<role>}/{system,home}` — `contexts/shared/system/<distro>` is the base tier every machine
  of that distro gets, `<role>` contexts carry role bits. A new machine is one composition entry in `nix/flake.nix`;
  machine keys in `linuxConfigurations` must equal the machine's short hostname. Anything user/system-facing
  ultimately flows through here.
- `agents/` — global instructions shared by all configured coding agents.
- `shell/` and `rust/` — shared shell behavior and Rust toolchain configuration.
- `btop/`, `direnv/`, `equaliser/`, `ghostty/`, `git/`, `gitui/`, `k9s/`, `kanata/`, `neovim/`, `starship/`,
  `tmux/`, `wezterm/`, and `yazi/` — tool-specific configuration.
- `wallpapers/` — platform theming assets.

## 4. Workflow Expectations
1. Prefer `nix fmt`, `nix flake check`, and attribute-scoped builds over bespoke scripts.
2. Never run `brew install` directly—Homebrew state is managed declaratively via `nix-homebrew` in `nix/modules/darwin`.
3. Do not open decrypted SOPS files; access values through the paths exposed in Home Manager modules (see `nix/contexts/work/home/default.nix`).

## 5. Environment Context
- `HOME_CONFIGURATION_CONTEXT` selects work/private shells, packages, and configuration. Preserve it when adding
  context-dependent modules.
- Work profile (`nix/contexts/work/home`) injects secrets for Docker registries, GitHub tokens, etc.; reference them via `config.sops.secrets.<name>.path`.
- Private profile (`nix/contexts/private/home`) focuses on zsh and Ollama; avoid work-only tooling there.
- `shell/common` provides shared GitUI theming, worktree cloning, and Docker helpers. Source it rather than duplicating
  logic.

## 6. Agent Sandbox and Security Intent
- Claude Code, Codex, and OpenCode run inside Nix-managed whole-process wrappers — that wrapper, not any agent-native
  permission policy, is the real filesystem boundary (covers the agent, tools, MCP servers, plugins, child processes).
  Documents, Pictures, `~/.ssh`, and SOPS-managed secrets are unreachable regardless of what a policy allows.
- Docker daemon access goes through `docker-agent-proxy` (`nix/pkgs/docker-agent-proxy`) on `/run/docker.sock`: normal
  traffic passes through, but container/volume creation bind-mounting a denied path (`~/.ssh`, SOPS secrets, etc.) is
  rejected rather than silently allowed.
- The launcher inherits the parent shell's environment but does not activate direnv and conceals its state dirs — an
  `.envrc` won't get auto-approved and cached direnv layouts from the calling shell aren't readable, so don't expect
  direnv-derived env vars unless they were already in the inherited environment.
- Sandbox config lives in `nix/lib/agents/` and `nix/modules/home-manager/agents/`, with platform install under
  `nix/modules/{nixos,darwin}/agents/`; edits need activation + an agent restart to take effect.

## 7. Code Style & Formatting
**General**
- 2-space indentation, 120-character soft limit unless a tool mandates otherwise.
- Favor small, composable modules and overlays; avoid monolithic files.
- Keep Catppuccin color choices consistent across shell prompts, terminals, themes, and UI configs.

**Nix**
- Alejandra formatting is canonical; never hand-wrap differently afterwards.
- Inputs should use `inputs.<name>.follows` where practical; avoid hard pin divergence without a comment.
- Modules belong under `nix/modules/<platform>/<topic>`; shared logic sits in `nix/modules/shared`.
- Prefer `lib.mkIf`, `lib.mkOptionDefault`, and `lib.optionals` to keep conditionals declarative.
- When adding Home Manager secrets, use the existing pattern in `nix/contexts/work/home/default.nix` (SOPS module import, `genAttrs` for multi-secret lists).

**Shell (bash/zsh)**
- Start scripts with `#!/usr/bin/env bash` and `set -e` (or `set -euo pipefail` if safe); keep functions in `shell/common` when they need cross-shell reuse.
- Use long-form function names; avoid single-letter aliases except where already established.
- Rely on built-in helpers from `shell/common` for git/distro detection; avoid copy/pasting OS detection logic.

**Lua / Neovim**
- Keep plugin specs under `neovim/logic/lua/plugins/`; language-specific configuration belongs in `neovim/logic/lua/lang/`.
- Stylua with default project settings (2 spaces, 120 columns). No trailing semicolons.
- When adding plugins, ensure they are hooked into the appropriate lazy loader and note dependencies inside the same table.

**TOML / YAML / JSON**
- Preserve key ordering that matches upstream tool docs (e.g., Starship, WezTerm). Alphabetize where no semantic order exists.
- Avoid trailing commas in TOML; keep double quotes for strings unless the format prefers bare words.

**Rust / Other Languages**
- Rust toolchain is managed via `rust/` and `rustup`; run `cargo fmt` + `cargo clippy` in affected projects before merging.
- Go/Node/Python tooling is typically project-local; when editing global helpers, prefer version managers provided via Home Manager (see `nix/contexts/work/home/global-dev-tools.nix`).

## 8. Error Handling & Logging
- In shell scripts, check command availability with `command -v` before use (see `init.sh`).
- Use descriptive `echo` statements or `printf` for user-facing messaging; keep debug logs minimal and optionally gated by an env var.
- For Nix modules, provide helpful option descriptions and default values; fail fast with assertions when an assumption must hold (e.g., context-specific host names).

## 9. Dependency & Package Guidance
- Add new system packages via the appropriate module (`nix/modules/darwin`, `nix/modules/nixos`, or shared overlays). Avoid `nix-env -i`.
- For Home Manager packages, prefer per-context modules (`contexts/work/home`, `contexts/private/home`) to avoid leaking work-only tools into private machines.
- Use overlays under `nix/overlays` to patch upstream packages; keep them minimal and documented.

## 10. Testing & Verification Tips
- Prefer the smallest relevant target build from section 2 before a full rebuild.
- When adjusting Neovim configs, open `nvim` and run `:checkhealth`.
- kanata's hardened systemd unit lives once in `kanata/kanata_linux.nix`; `kanata_install_nixos.nix` and
  `kanata_install_system_manager.nix` only add the platform's uinput plumbing. macOS uses `kanata_install_darwin.nix`.
- On new hosts, test via `kanata --cfg kanata/kanata_us.kbd` before enabling the service at boot.

## 11. Commit & Review Hygiene
- Commit messages here are ultra-short: one lowercase subject line, a few words, no trailing period, no body, no
  conventional-commit type prefix — check `git log` for the going style before proposing one.
- Prepare diffs with `git status` and `git diff` for inspection.
- Reference changed files by path + line numbers in final summaries so users can jump straight to them.
- Mention any follow-up work (e.g., “needs `nix flake update`”) instead of silently skipping it.

## 12. Miscellaneous Tips
- Formatting-on-save is generally enabled Neovim. Temporarily disable with `:FormatDisable` only if a formatter is broken, and re-enable afterwards.
- Catppuccin theme variants: prefer Mocha for dark, Latte for light, and keep prompt/terminal/Neovim in sync.
- `gitui` theme auto-detects platform and color scheme via `shell/common`—reuse that function rather than introducing new env checks.
- When touching MCP server definitions, ensure runtime inputs exist on both darwin (`aarch64-darwin`) and linux (`x86_64-linux`) systems.

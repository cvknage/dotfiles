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
- MCP servers (NixOS, Context7, etc.) are configured in `nix/modules/home/agents/mcp`; prefer using them whenever applicable.

## 2. Command Reference (Build/Lint/Test)
- **Flake validation:** `nix flake check ./nix` — evaluates recognized outputs and runs checks for the current system.
- **NixOS target:** `nix build ./nix#nixosConfigurations.penguin-tuxedo.config.system.build.toplevel`.
- **macOS target:** `nix build ./nix#darwinConfigurations.logic.system`.
- **Home Manager target:** `nix build './nix#homeConfigurations."ckn@work".activationPackage'`.
- **System Manager target:** `nix build ./nix#systemConfigs.fedora`.
- **macOS rebuild:** `sudo darwin-rebuild switch --flake ./nix` (automatically manages Homebrew through `nix-homebrew`).
- **NixOS rebuild:** `sudo nixos-rebuild switch --flake ./nix` (pulls in shared + host-specific modules).
- **Standalone Home Manager:** `home-manager switch --flake './nix#ckn@work'` — one configuration for every
  standalone Linux work host, regardless of hostname or distro.
- **Fedora rebuild:** `nix run ./nix#fedora-rebuild ./nix` — applies the System Manager tier then the Home Manager
  tier. The flake directory is optional and defaults to `~/.dotfiles/nix`; comes from `nix/lib/rebuild-app.nix`.
  Individual tier: `nix run github:numtide/system-manager -- switch --flake ./nix#fedora --sudo`.
- **Distro prerequisites:** `bash nix/hosts/<distro>/bootstrap.sh` installs the host-owned packages the Nix tiers
  depend on. Idempotent, and elevates only when something is missing.
- **Fedora is experimental:** System Manager only asserts support for nixos, ubuntu and debian, so
  `nix/hosts/fedora/configuration.nix` sets `system-manager.allowAnyDistro`.
- **Standalone agent policy:** after every standalone Home Manager switch, run
  `sudo nix run ./nix#install-agent-policy`. Not needed where a system tier exists, which owns the
  `/etc` policy via `nix/modules/agents/system.nix`.
- **Format Nix:** `nix fmt ./nix` (Alejandra via flake). For single files: `alejandra path/to/file.nix` if available.
- **Lua formatting:** `cd neovim && stylua .` (configs expect 2 spaces / 120 cols; formatting on save is normally enabled).
- **Shell linting:** use `bash -n script.sh` for syntax checks and `shellcheck script.sh` (install via Nix if missing) before committing substantive shell changes.

## 3. Repo Map & Ownership
- `nix/` — flakes, overlays, modules, and home profiles (`work`, `private`, `shared`). Anything user/system-facing ultimately flows through here.
- `agents/` — global instructions shared by all configured coding agents.
- `shell/` and `rust/` — shared shell behavior and Rust toolchain configuration.
- `btop/`, `direnv/`, `equaliser/`, `ghostty/`, `git/`, `gitui/`, `k9s/`, `kanata/`, `neovim/`, `starship/`,
  `tmux/`, `wezterm/`, `xkb/`, and `yazi/` — tool-specific configuration.
- `wallpapers/` — platform theming assets.

## 4. Workflow Expectations
1. Prefer `nix fmt`, `nix flake check`, and attribute-scoped builds over bespoke scripts.
2. Never run `brew install` directly—Homebrew state is managed declaratively via `nix-homebrew` in `nix/modules/darwin`.
3. Do not open decrypted SOPS files; access values through the paths exposed in Home Manager modules (see `nix/homes/work/default.nix`).

## 5. Environment Context
- `HOME_CONFIGURATION_CONTEXT` selects work/private shells, packages, and configuration. Preserve it when adding
  context-dependent modules.
- Work profile (`nix/homes/work`) injects secrets for Docker registries, GitHub tokens, etc.; reference them via `config.sops.secrets.<name>.path`.
- Private profile (`nix/homes/private`) focuses on zsh and Ollama; avoid work-only tooling there.
- `shell/common` provides shared GitUI theming, worktree cloning, and Docker helpers. Source it rather than duplicating
  logic.

## 6. Agent Sandbox and Security Intent

- The goal is a practical privacy boundary, not complete isolation from the development machine. Agents should be able
  to work autonomously in `~/.dotfiles` and `~/code` (`~/Code` on macOS), use project flakes and direnv environments,
  write to selected development caches, and interact with approved local services.
- Claude Code, Codex, and OpenCode are launched through Nix-managed whole-process wrappers. The wrapper is the primary
  filesystem boundary and applies to the agent, its tools, MCP servers, plugins, and child processes. Personal and
  credential locations such as Documents, Pictures, `.ssh`, and SOPS-managed secrets remain unavailable.
- Agent-native permission policies provide additional command and tool controls, but are not the filesystem boundary.
  Root-owned managed policy is installed by the system configuration. For Claude Code, an organization-provided remote
  managed policy remains authoritative when present; otherwise the system-managed policy applies. Nix owns the security
  keys in mutable user settings while preserving unrelated runtime and plugin settings.
- Docker remains rootful for compatibility with existing Taskfiles, Testcontainers, kind, and other development tools.
  The Docker and containerd services receive a restricted filesystem view matching the agent boundary, allowing normal
  container workflows without exposing unrelated private host data.
- The launcher activates an allowed project direnv environment before starting the agent so flake-provided compilers and
  tools are available without granting broad access to the host filesystem.
- Security behavior is defined in `nix/modules/shared/agents/` and `nix/modules/home/agents/`, with platform
  installation under `nix/modules/nixos/agents/` and `nix/modules/darwin/agents/`. Configuration changes become effective
  only after activation and an agent restart.

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
- When adding Home Manager secrets, use the existing pattern in `nix/homes/work/default.nix` (SOPS module import, `genAttrs` for multi-secret lists).

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
- Go/Node/Python tooling is typically project-local; when editing global helpers, prefer version managers provided via Home Manager (see `nix/homes/work/global-dev-tools.nix`).

## 8. Error Handling & Logging
- In shell scripts, check command availability with `command -v` before use (see `init.sh`).
- Use descriptive `echo` statements or `printf` for user-facing messaging; keep debug logs minimal and optionally gated by an env var.
- For Nix modules, provide helpful option descriptions and default values; fail fast with assertions when an assumption must hold (e.g., context-specific host names).

## 9. Dependency & Package Guidance
- Add new system packages via the appropriate module (`nix/modules/darwin`, `nix/modules/nixos`, or shared overlays). Avoid `nix-env -i`.
- For Home Manager packages, prefer per-context modules (`homes/work`, `homes/private`) to avoid leaking work-only tools into private machines.
- Use overlays under `nix/overlays` to patch upstream packages; keep them minimal and documented.

## 10. Testing & Verification Tips
- Prefer the smallest relevant target build from section 2 before a full rebuild.
- When adjusting Neovim configs, open `nvim` and run `:checkhealth`.
- kanata's hardened systemd unit lives once in `kanata/kanata_linux.nix`; `kanata_install_nixos.nix` and
  `kanata_install_system_manager.nix` only add the platform's uinput plumbing. macOS uses `kanata_install_darwin.nix`.
- On new hosts, test via `kanata --cfg kanata/kanata_us.kbd` before enabling the service at boot.

## 11. Commit & Review Hygiene
- Prepare diffs with `git status` and `git diff` for inspection.
- Reference changed files by path + line numbers in final summaries so users can jump straight to them.
- Mention any follow-up work (e.g., “needs `nix flake update`”) instead of silently skipping it.

## 12. Miscellaneous Tips
- Formatting-on-save is generally enabled Neovim. Temporarily disable with `:FormatDisable` only if a formatter is broken, and re-enable afterwards.
- Catppuccin theme variants: prefer Mocha for dark, Latte for light, and keep prompt/terminal/Neovim in sync.
- `gitui` theme auto-detects platform and color scheme via `shell/common`—reuse that function rather than introducing new env checks.
- When touching MCP server definitions, ensure runtime inputs exist on both darwin (`aarch64-darwin`) and linux (`x86_64-linux`) systems.

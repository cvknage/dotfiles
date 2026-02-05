# `.dotfiles` Agent Guide

> Repo-scoped instructions for anyone automating or editing this configuration. Global guardrails still live in `opencode/AGENTS.md`.
>
> Stretch goal: keep this file ~150 lines so it is readable end-to-end during a run.

## 0. Mental Model
1. This repository is the single source of truth for macOS (nix-darwin), NixOS, and standalone Home Manager environments.
2. Everything is orchestrated through the flake in `nix/`; resist ad-hoc OS/package changes.
3. Secrets are delivered via `sops-nix` + the `secrets` flake input—never open decrypted payloads, only reference the managed paths.

## 1. Getting Set Up
- Run `bash init.sh` once after cloning; it links `~/.dotfiles`, installs Nix if needed, then performs the appropriate rebuild (`darwin-rebuild`, `nixos-rebuild`, or `home-manager switch`).
- Direnv is configured via `direnv/direnvrc` and `direnv.toml`; allow it so devshells inject env vars and MCP tokens automatically.
- MCP servers (filesystem, nixos, context7, etc.) are configured in `nix/modules/home/mcp`; prefer using the provided MCP tasks + skills whenever possible.

## 2. Command Reference (Build/Lint/Test)
- **Full validation:** `nix flake check ./nix` — builds all outputs (darwin, nixos, home-manager) and runs any defined checks.
- **macOS rebuild:** `sudo darwin-rebuild switch --flake ./nix` (automatically manages Homebrew through `nix-homebrew`).
- **NixOS rebuild:** `sudo nixos-rebuild switch --flake ./nix` (pulls in shared + host-specific modules).
- **Standalone Home Manager:** `home-manager switch --flake ./nix#<user>@<host>`; default attr is `chris@full-tuxedo` for the Linux HM-only case.
- **Single target build ("single test")**: use `nix build ./nix#darwinConfigurations.logic.system` (or another attribute like `.#nixosConfigurations.penguin-tuxedo.config.system.build.toplevel`) to isolate one output instead of running every check.
- **Format Nix:** `nix fmt ./nix` (Alejandra via flake). For single files: `alejandra path/to/file.nix` if available.
- **Lua formatting:** `cd neovim && stylua .` (configs expect 2 spaces / 120 cols; formatting on save is normally enabled).
- **Shell linting:** use `bash -n script.sh` for syntax checks and `shellcheck script.sh` (install via Nix if missing) before committing substantive shell changes.
- **Neovim health:** open Neovim and run `:checkhealth` when touching plugin/runtime changes.
- **Kanata configs:** rebuild through the flake; for ad-hoc tests run `kanata --config path/to/config.kbd`.

## 3. Repo Map & Ownership
- `nix/` — flakes, overlays, modules, and home profiles (`work`, `private`, `shared`). Anything user/system-facing ultimately flows through here.
- `shell/` — shared shell glue and per-shell snippets; sourced via Home Manager modules.
- `neovim/`, `starship/`, `ghostty/`, `wezterm/`, `tmux/`, `kanata/`, `wezterm/`, `git/`, etc. — tool-specific configs; edit in place and keep Catppuccin palette alignment.
- `equaliser/`, `wezterm/`, `ghostty/`, `wallpapers/` — platform-adjacent assets (audio routing, terminal profile, theming, imagery).
- `opencode/` — skills, commands, and MCP agent definitions exposed to agents; tweak only if you understand how the automation uses them.

## 4. Workflow Expectations
1. Read before you edit; respect scope-specific instructions (no nested `AGENTS.md` today, but check before deep changes).
2. Keep one TodoWrite item `in_progress` at a time; update as you move through subtasks.
3. Prefer `nix fmt`, `nix flake check`, and attribute-scoped builds over bespoke scripts.
4. Never run `brew install` directly—Homebrew state is managed declaratively via `nix-homebrew` in `nix/modules/darwin`.
5. Do not open decrypted SOPS files; access values through the paths exposed in Home Manager modules (see `nix/homes/work/default.nix`).

## 5. Environment Context
- `HOME_CONFIGURATION_CONTEXT` differentiates “work” vs “private” profiles and toggles shells (bash vs zsh) plus MCP servers. Preserve this variable when adding new modules.
- Work profile (`nix/homes/work`) injects secrets for Docker registries, GitHub tokens, etc.; reference them via `config.sops.secrets.<name>.path`.
- Private profile (`nix/homes/private`) focuses on zsh and Ollama; avoid work-only tooling there.
- `shell/common` provides shared aliases (gitui theming, Docker helpers, mirrord integration). Source it rather than duplicating logic.

## 6. Code Style & Formatting
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

## 7. Error Handling & Logging
- In shell scripts, check command availability with `command -v` before use (see `init.sh`).
- Use descriptive `echo` statements or `printf` for user-facing messaging; keep debug logs minimal and optionally gated by an env var.
- For Nix modules, provide helpful option descriptions and default values; fail fast with assertions when an assumption must hold (e.g., context-specific host names).

## 8. Dependency & Package Guidance
- Add new system packages via the appropriate module (`nix/modules/darwin`, `nix/modules/nixos`, or shared overlays). Avoid `nix-env -i`.
- For Home Manager packages, prefer per-context modules (`homes/work`, `homes/private`) to avoid leaking work-only tools into private machines.
- Use overlays under `nix/overlays` to patch upstream packages; keep them minimal and documented.
- When adding binary blobs (wallpapers, themes), store them under the most specific directory and reference them declaratively via modules.

## 9. Testing & Verification Tips
- After editing a module, run `nix repl ./nix` and `:lf` the module to ensure evaluation succeeds before a full rebuild.
- For incremental checks, target specific attributes: `nix eval ./nix#homeConfigurations."chris@full-tuxedo".activationPackage` to ensure the HM profile builds.
- When adjusting Neovim configs, open Neovim with `NVIM_APPNAME=logic nvim` (if applicable) to ensure the correct runtime is used.
- For kanata configs on non-NixOS hosts, follow `kanata/kanata_install_darwin.nix` and test via `kanata --config ...` before enabling at boot.

## 10. Commit & Review Hygiene
- Never commit without explicit user approval. Prepare diffs with `git status` + `git diff` for inspection.
- Reference changed files by path + line numbers in final summaries so users can jump straight to them.
- Mention any follow-up work (e.g., “needs `nix flake update`”) instead of silently skipping it.

## 11. Miscellaneous Tips
- Formatting-on-save is generally enabled Neovim. Temporarily disable with `:FormatDisable` only if a formatter is broken, and re-enable afterwards.
- Catppuccin theme variants: prefer Mocha for dark, Latte for light, and keep prompt/terminal/Neovim in sync.
- `gitui` theme auto-detects platform and color scheme via `shell/common`—reuse that function rather than introducing new env checks.
- When touching MCP server definitions, ensure runtime inputs exist on both darwin (`aarch64-darwin`) and linux (`x86_64-linux`) systems.
- Large binary additions (fonts, wallpapers) should include a short README in the containing directory explaining provenance and usage.

Happy automating! Stay declarative, keep secrets sealed, and let `nix` do the heavy lifting.

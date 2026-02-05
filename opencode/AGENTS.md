# OpenCode Agent Guidelines

Global automation and safety rules for any repository managed by this system (not just Nix work). This file is symlinked to `~/.config/opencode/AGENTS.md`.

## Repository Safety

- Never run `git push` or modify remotes unless explicitly instructed.
- Never commit without explicit user approval.
- Confirm before destructive commands (`git reset --hard`, `rm -rf`, etc.).

## Workflow Expectations

- Treat flakes as the source of truth: prefer `nix flake check`, `nix build .#target`, `nix fmt`, and sanctioned `nix develop` devshells.
- Enter the appropriate devshell (or `direnv allow`) before running tools so secrets, env vars, and MCP tokens are injected.
- Keep `flake.lock` changes intentional—use `nix flake update` (optionally with an input name) rather than editing by hand.

## Platform Commands

Use the rebuild/apply command that matches the host:
- macOS (nix-darwin): `sudo darwin-rebuild switch --flake .`
- NixOS: `sudo nixos-rebuild switch --flake .`
- Home Manager only: `home-manager switch --flake .`

## MCP & Specialized Skills

- Prefer MCP servers (filesystem, NixOS, Context7, etc.) and specialized skills before ad-hoc searches.
- When editing `*.nix`, start with the Nix-focused skills (`flake-editor`, `home-manager-helper`, `nix-module-author`, `nixos-option-lookup`, `nix-debugger`) before falling back to raw file reads or manual reasoning.

## Task & File Handling

- Use TodoWrite/TodoRead for multi-step tasks; keep one task `in_progress` at a time.
- Always read a file before editing; preserve indentation and formatters (Alejandra, stylua, etc.).
- Avoid creating new documentation files unless requested; prefer updating existing scoped docs.

## Scope Reminder

When working specifically on the `.dotfiles` repository, also consult the repo-local `AGENTS.md` at the project root for layout, secrets, Homebrew, and context-specific rules.

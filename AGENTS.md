# AGENTS.md

## Overview
These are the dotfiles for setting up a Nix-managed environment supporting macOS (using nix-darwin) and Linux (NixOS or Home Manager). These configurations include tools for development workflows, shell setups, and utilities with shared and per-platform logic.

---

## Repository Structure

Here’s an overview of the organization:

- **`nix/`**: Contains flakes and modules for system configuration.
  - `flake.nix`: Entry point for Nix configurations.
  - `homes/`: Home Manager configurations for `work` and `private` contexts.
- **`shell/`**: Unified and shell-specific scripting.
  - `common`: Shared aliases, functions, and paths.
  - `bash/` and `zsh/`: Context-specific settings.
- **`neovim/`**: Custom Lua-based Neovim configurations (modular plugins and options).
- **`starship/`**: Prompt customization with Starship (Catppuccin theme).
- **`ghostty/`**: Ghostty terminal multiplexer configuration (preferred).
- **`wezterm/`**: WezTerm terminal multiplexer configuration.
- **`equaliser/`**: AU Lab and Easy Effects audio profiles.
- **Tooling**:
  - `tmux/`: Session persistence and navigation.
  - `k9s/`: Kubernetes visualization.
  - `btop/`: Resource monitoring.
  - `kanata/`: Keyboard remapping.

---

## Build, Apply, and Initialization Commands

### Initializing Dotfiles
Run the following to initialize everything after cloning the repository:
```bash
bash init.sh
```

### Apply System Configurations

Ensure you are in the repository's root directory, as commands reference the `./nix` folder.

Based on the platform:

1. **NixOS**:
   ```bash
   sudo nixos-rebuild switch --flake ./nix
   ```

2. **macOS**:
   ```bash
   sudo darwin-rebuild switch --flake ./nix
   ```

3. **Other Linux (Home Manager)**:
   ```bash
   home-manager switch --flake ./nix
   ```

4. **Validate Nix Configurations**:
   ```bash
   nix flake check ./nix
   ```

5. Any additional tools are initialized by running the `init.sh` files inside each tool’s folder.

---

## Validation & Testing
While this is a dotfiles repo, you can validate:

- **Nix** configurations:
  ```bash
  nix flake check ./nix
  ```
- **Neovim** health:
  - `:checkhealth`
  - `:Lazy check` (plugin health)
- **Interactive Testing**:
  - Shell scripts can be tested by sourcing scripts and running interactively.

---

## Code Style Guidelines

### General
- **Indentation**: 2 spaces, no tabs.
- **Line Length**: Maximum 120 characters.

### Nix Files
- Follow strict formatting conventions using **alejandra**.
- Prefer `inputs.follows` patterns for consistency.

### Lua Files
- Formatting: Use **stylua** with:
  - Indentation: 2 spaces.
  - Line Length: 120 characters.
- Plugins:
  - Plugins are modularized under `neovim/logic/lua/plugins/`.
  - Organize language-specific plugins in the `lang/` subdirectory.

### Shell Scripts
- Shebang: `#!/usr/bin/env bash`
- Always include `set -e` to exit on error.
- Prefer functions over inline commands.
- Example:
  ```bash
  # Alias for listing
  alias ll='ls -lah'

  # A themed gitui launcher
  function gitui_themed() {
    gitui -t catppuccin-mocha.ron
  }
  ```

### TOML/YAML Files
- Follow consistent key ordering and indentation.
- Example TOML from Starship prompt:
  ```toml
  format = "[username: $username]($style)"
  [directory]
    truncation_length = 3
  ```

---

## Neovim Plugin Structure
- Default structure:
  - Treesitter for syntax highlighting.
  - Mason for managing LSPs and formatters.
  - Conform for formatting.
  - Linters defined in `nvim-lint`.
  - Debugging via `nvim-dap` with optional adapters.
- Example from Lua:
  ```lua
  require('mason').setup {
    ensure_installed = {
      'lua-language-server',
      'stylua',
    }
  }
  ```

---

## Common Gotchas
- **Themes**:
  - Catppuccin is used across tools (Neovim, Starship, gitui).
- **Secrets**:
  - Managed via **sops-nix** and referenced in Nix flakes.
- **Shell Contexts**:
  - Work uses Bash; private uses Zsh.
- **Formatters**:
  - Autoformat on save is enabled by default; disable with:
    ```
    :FormatDisable
    ```

Happy coding!

---

## Rules
- Never commit without explicit user approval

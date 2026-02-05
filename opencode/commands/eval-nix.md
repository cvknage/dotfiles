---
description: Evaluate a Nix expression or attribute via MCP/Nix CLI.
agent: nix-specialist
---

Evaluate the provided Nix expression `$ARGUMENTS`.  
Return:
- The evaluated result or error.
- If error, the minimal reproduction and recommended fix.
Example inputs:
- `nix repl '<flake>?#foo'`
- `nix eval .#packages.x86_64-linux.hello`


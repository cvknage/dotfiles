#!/usr/bin/env bash
#
# Enters the bootstrap devShell with the private secrets input stubbed out, so it
# works on a host whose deploy key is not authorized yet. Arguments run inside the
# shell; with none, an interactive shell opens.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_DIR="$(dirname "$SCRIPT_DIR")"

NIX_CONFIG="$(printf '%s\nextra-experimental-features = nix-command flakes' "${NIX_CONFIG:-}")"
export NIX_CONFIG

# path: rather than a git ref, so the stub needs no commit, and
# --no-write-lock-file so the substitution can never land in flake.lock.
exec nix develop "$NIX_DIR#default" \
  --override-input secrets "path:$NIX_DIR/stubs/secrets" \
  --no-write-lock-file \
  "$@"

#!/usr/bin/env bash
#
# Per-machine setup for the private dotfiles-secrets flake input: one keypair
# acting as both GitHub deploy key (fetch) and sops age identity (decrypt).
# Idempotent. Exits 1 with instructions until the deploy key is authorized.
set -euo pipefail

# A fresh NixOS install has flakes disabled. Appended, so an existing
# NIX_CONFIG survives, and additive, so enabled features are kept.
NIX_CONFIG="$(printf '%s\nextra-experimental-features = nix-command flakes' "${NIX_CONFIG:-}")"
export NIX_CONFIG

SECRETS_REPO="cvknage/dotfiles-secrets"
KEY="$HOME/.ssh/keys/dotfiles-secrets"

if [ ! -f "$KEY" ]; then
  mkdir -p "$(dirname "$KEY")"
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "dotfiles-secrets@$(hostname)"
  echo "Generated $KEY"
else
  echo "Keypair already exists: $KEY"
fi

# Stand-in for the github-secrets ssh alias, which the system config only writes after a successful rebuild.
NO_ALIAS_SSH="ssh -i $KEY -o IdentitiesOnly=yes -o Hostname=github.com -o User=git -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# Prime the input into the nix store for the first rebuild; doubles as the
# deploy-key authorization check.
if GIT_SSH_COMMAND="$NO_ALIAS_SSH" \
  nix flake prefetch "git+ssh://github-secrets/$SECRETS_REPO" >/dev/null; then
  # sudo rebuilds evaluate as root with separate fetch caches; prime those too until the system ssh alias exists.
  if { [ "$(uname)" = "Darwin" ] || [ -e /etc/NIXOS ]; } && ! grep -qrs 'Host github-secrets' /etc/ssh/; then
    # Via `env`, so sudo's env_reset cannot drop these; it only filters
    # variables assigned to sudo itself, not arguments to the command.
    sudo env GIT_SSH_COMMAND="$NO_ALIAS_SSH" NIX_CONFIG="$NIX_CONFIG" \
      nix flake prefetch "git+ssh://github-secrets/$SECRETS_REPO" >/dev/null
  fi
  echo "Deploy key is authorized; $SECRETS_REPO is primed in the nix store."
  exit 0
fi

AGE_RECIPIENT="$(nix run nixpkgs#ssh-to-age -- -i "$KEY.pub")"
cat <<EOF

========================================================================
NEXT STEPS
========================================================================

1. Add this machine as a READ-ONLY deploy key (do NOT tick "write"):
   https://github.com/$SECRETS_REPO/settings/keys

   $(cat "$KEY.pub")

2. From a machine that can already decrypt, add this age recipient to
   .sops.yaml in $SECRETS_REPO, then re-encrypt and push:

   $AGE_RECIPIENT

   sops updatekeys secrets/secrets.yaml

3. Re-run this script (or init.sh) to verify.
========================================================================
EOF
exit 1

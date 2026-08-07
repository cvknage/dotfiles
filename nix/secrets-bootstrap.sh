#!/usr/bin/env bash
#
# Per-machine setup for the private dotfiles-secrets flake input: one keypair
# acting as both GitHub deploy key (fetch) and sops age identity (decrypt).
# The ssh alias and age identity are declared in nix/homes/shared/secrets.nix;
# only creating the key and priming the store can't be declarative.
# Idempotent. Exits 1 with instructions until the deploy key is authorized.
set -euo pipefail

SECRETS_REPO="cvknage/dotfiles-secrets"
KEY="$HOME/.ssh/dotfiles-secrets"

if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "dotfiles-secrets@$(hostname)"
  echo "Generated $KEY"
else
  echo "Keypair already exists: $KEY"
fi

# The github-secrets ssh alias is written by the system config, i.e. only
# exists after a successful rebuild — but the rebuild needs to fetch this
# input. These ssh options substitute for the alias to break that cycle.
NO_ALIAS_SSH="ssh -i $KEY -o IdentitiesOnly=yes -o Hostname=github.com -o User=git -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# Fetch the input once, out of band. Locked inputs resolve from the store by
# hash, so the rebuild itself then needs no network — which also keeps sudo
# rebuilds working (root never sees the user's ssh config).
# Doubles as the "is the deploy key authorized" check.
if GIT_SSH_COMMAND="$NO_ALIAS_SSH" \
  nix flake prefetch "git+ssh://github-secrets/$SECRETS_REPO" >/dev/null; then
  # A stale flake.lock would make the rebuild fetch anyway; re-lock here.
  FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if ! grep -q 'github-secrets' "$FLAKE_DIR/flake.lock"; then
    GIT_SSH_COMMAND="$NO_ALIAS_SSH" nix flake update secrets --flake "$FLAKE_DIR"
    echo "Re-locked the secrets input in $FLAKE_DIR/flake.lock"
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

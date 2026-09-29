#!/usr/bin/env bash
#
# Per-machine setup for the private dotfiles-secrets flake input. Two keys: an
# ed25519 SSH keypair that is the GitHub deploy key (fetch), and a post-quantum
# age identity that decrypts.
#
# Idempotent. Run it via nix/scripts/bootstrap-shell.sh, which puts age and sops
# on PATH.
#
# Exits:
#   0  this host is set up, including when its identity is not registered yet
#   2  a step failed; the error above says which
#   3  instructions were printed; act on them and re-run
set -euo pipefail

for tool in age-keygen sops; do
  command -v "$tool" >/dev/null || {
    echo "$tool is not on PATH; run this via nix/scripts/bootstrap-shell.sh" >&2
    exit 2
  }
done

# -pq needs age 1.3; post-quantum identities need sops 3.12. A direct run picks
# up whatever distro or Homebrew tooling happens to be on PATH.
age-keygen -h 2>&1 | grep -q -- '-pq' || {
  echo "this age-keygen has no -pq; run this via nix/scripts/bootstrap-shell.sh" >&2
  exit 2
}
sops_release="$(sops --version 2>/dev/null | head -n1 | awk '{split($2,v,"."); if (v[1]+0>0 && v[2]+0>0) print v[1]*100+v[2]}')"
# Only a legible, definitely-old version is rejected: an unfamiliar format must
# not block the run.
if [ -n "$sops_release" ] && [ "$sops_release" -lt 312 ]; then
  echo "this sops predates 3.12 and cannot read a post-quantum identity; run this via nix/scripts/bootstrap-shell.sh" >&2
  exit 2
fi

# A fresh NixOS install has flakes disabled. Appended, so an existing
# NIX_CONFIG survives, and additive, so enabled features are kept.
NIX_CONFIG="$(printf '%s\nextra-experimental-features = nix-command flakes' "${NIX_CONFIG:-}")"
export NIX_CONFIG

SECRETS_REPO="cvknage/dotfiles-secrets"
DEPLOY_KEY="$HOME/.ssh/keys/dotfiles-secrets"
AGE_KEY="$HOME/.ssh/keys/dotfiles-secrets-pq"

if [ ! -f "$DEPLOY_KEY" ]; then
  mkdir -p "$(dirname "$DEPLOY_KEY")"
  ssh-keygen -t ed25519 -f "$DEPLOY_KEY" -N "" -C "dotfiles-secrets@$(hostname)"
  echo "Generated deploy key $DEPLOY_KEY"
else
  echo "Deploy key already present: $DEPLOY_KEY"
fi

if [ ! -f "$AGE_KEY" ]; then
  mkdir -p "$(dirname "$AGE_KEY")"
  age-keygen -pq -o "$AGE_KEY"
  chmod 600 "$AGE_KEY"
  echo "Generated post-quantum age identity $AGE_KEY"
else
  echo "Post-quantum age identity already present: $AGE_KEY"
fi

AGE_RECIPIENT="$(age-keygen -y "$AGE_KEY")"

# Stand-in for the github-secrets ssh alias, which the system config only writes after a successful rebuild.
NO_ALIAS_SSH="ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes -o Hostname=github.com -o User=git -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

if PREFETCH_JSON="$(GIT_SSH_COMMAND="$NO_ALIAS_SSH" \
  nix flake prefetch --json "git+ssh://github-secrets/$SECRETS_REPO")"; then
  SECRETS_PATH="$(printf '%s' "$PREFETCH_JSON" | grep -o '"storePath":"[^"]*"' | cut -d'"' -f4)"
  [ -n "$SECRETS_PATH" ] || {
    echo "Could not read storePath out of \`nix flake prefetch --json\`" >&2
    exit 2
  }

  # sudo rebuilds evaluate as root with separate fetch caches; prime those too until the system ssh alias exists.
  if { [ "$(uname)" = "Darwin" ] || [ -e /etc/NIXOS ]; } && ! grep -qrs 'Host github-secrets' /etc/ssh/; then
    # Via `env`, so sudo's env_reset cannot drop these; it only filters
    # variables assigned to sudo itself, not arguments to the command.
    if ! sudo env GIT_SSH_COMMAND="$NO_ALIAS_SSH" NIX_CONFIG="$NIX_CONFIG" \
      nix flake prefetch "git+ssh://github-secrets/$SECRETS_REPO" >/dev/null; then
      echo "Could not prime root's fetch cache for $SECRETS_REPO." >&2
      exit 2
    fi
  fi

  # The deploy key proves the fetch; decrypting is the other key's job.
  if sops_error="$(SOPS_AGE_KEY_FILE="$AGE_KEY" sops -d "$SECRETS_PATH/secrets/secrets.yaml" 2>&1 >/dev/null)"; then
    echo "Deploy key authorized and age identity registered; $SECRETS_REPO is primed in the nix store."
    exit 0
  fi

  cat <<EOF

------------------------------------------------------------------------
This host's age identity could not decrypt $SECRETS_REPO. sops said:

  $sops_error

If that is a missing/unsupported identity or no match against the recipients,
it is expected until the recipient below is registered and the files are
re-encrypted. If it names anything else -- a version gap, a missing file, a
path that does not exist -- fix that instead.

  $AGE_RECIPIENT

Add it to .sops.yaml, then re-encrypt every file this machine should read with
\`sops updatekeys\`.
------------------------------------------------------------------------
EOF
  exit 0
fi

cat <<EOF

========================================================================
NEXT STEPS
========================================================================

1. Add this machine as a READ-ONLY deploy key (do NOT tick "write"):
   https://github.com/$SECRETS_REPO/settings/keys

   $(cat "$DEPLOY_KEY.pub")

2. From a machine that can already decrypt, add this age recipient to
   .sops.yaml, then re-encrypt every file this machine should read with
   \`sops updatekeys\`:

   $AGE_RECIPIENT

3. Re-run this script (or init.sh) to verify.
========================================================================
EOF
exit 3

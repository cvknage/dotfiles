#!/usr/bin/env bash
set -euo pipefail

# Runs from the repo bootstrap's per-directory loop under `set -e`; every path must exit 0.

command -v herdr >/dev/null && command -v jq >/dev/null || exit 0

# `herdr plugin install` needs a running server; `status server` exits 0 either way, so read its output.
herdr status server 2>/dev/null | grep -q "status: running" || exit 0

# The list and lock live in the repo, next to this script.
lock="$(dirname "${BASH_SOURCE[0]}")/plugins/config/herdr-lazy/plugins.lock"

# herdr-lazy isn't on PATH; its binary lives in its plugin root.
herdr_lazy_root() {
  herdr plugin list --json | jq -r '[.result.plugins[]? | select(.plugin_id == "herdr-lazy") | .plugin_root] | first // empty'
}

# Pin the bootstrap install to the lock's commit, so a fresh machine cannot install a
# newer herdr-lazy than the lock it will then be asked to restore.
herdr_lazy_ref="$(sed -n 's#^natori-hrj/herdr-lazy@##p' "$lock" 2>/dev/null | head -n1 || true)"
plugin_root="$(herdr_lazy_root || true)"
if [ -z "$plugin_root" ]; then
  if [ -n "$herdr_lazy_ref" ]; then
    herdr plugin install natori-hrj/herdr-lazy --ref "$herdr_lazy_ref" --yes || true
  else
    herdr plugin install natori-hrj/herdr-lazy --yes || true
  fi
  plugin_root="$(herdr_lazy_root || true)"
fi
if [ -z "$plugin_root" ]; then
  echo "init.sh: herdr-lazy not found after install; plugins not synced" >&2
  exit 0
fi

# restore reproduces the lock; sync is the fallback when there is none.
herdr_lazy="$plugin_root/target/release/herdr-lazy"
synced=0
if [ -f "$lock" ]; then
  if "$herdr_lazy" restore; then synced=1; else echo "init.sh: herdr-lazy restore failed; plugins not synced" >&2; fi
else
  if "$herdr_lazy" sync; then synced=1; else echo "init.sh: herdr-lazy sync failed; plugins not synced" >&2; fi
fi

# Apply config.toml on a server that may have started before it was deployed.
if [ "$synced" = 1 ]; then
  herdr server reload-config >/dev/null 2>&1 || true
fi

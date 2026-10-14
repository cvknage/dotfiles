#!/usr/bin/env bash
set -euo pipefail

base_ref=${1:?usage: seed-code-graph.sh <base-ref> <target-dir>}
target=${2:?usage: seed-code-graph.sh <base-ref> <target-dir>}

branch=$base_ref
if [ "$branch" = HEAD ]; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
fi
for remote in $(git remote); do
  branch=${branch#"$remote"/}
done
base_dir=$(git worktree list --porcelain |
  awk -v ref="refs/heads/$branch" '/^worktree /{path = substr($0, 10)} $0 == "branch " ref {print path}')
if [ -z "$base_dir" ]; then
  echo "seed-code-graph: no worktree has ${branch:-$base_ref} checked out, not seeding"
  exit 0
fi

source_db="$base_dir/.code-graph/index.db"
if [ ! -f "$source_db" ]; then
  echo "seed-code-graph: $base_dir has no index, not seeding"
  exit 0
fi

if [ ! -d "$target" ]; then
  echo "seed-code-graph: $target does not exist, not seeding"
  exit 0
fi

target_db="$target/.code-graph/index.db"
if [ -e "$target_db" ]; then
  echo "seed-code-graph: $target already has an index, not seeding"
  exit 0
fi

mkdir -p "$target/.code-graph"
partial="$target_db.partial"
if python3 -I - "$source_db" "$partial" <<'PY'
import sqlite3
import sys

source = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
target = sqlite3.connect(sys.argv[2])
source.backup(target)
target.close()
source.close()
PY
then
  mv "$partial" "$target_db"
  echo "seed-code-graph: seeded $target from $base_dir"
else
  rm -f "$partial"
  echo "seed-code-graph: could not back up $source_db, not seeding"
fi

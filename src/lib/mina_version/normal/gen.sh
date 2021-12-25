#!/usr/bin/env bash
set -euo pipefail

branch="${MINA_BRANCH-$(git rev-parse --verify --abbrev-ref HEAD || echo "<unknown>")}"

# we are nested 6 directories deep (_build/<context>/src/lib/mina_version/normal)
pushd ../../../../../..
  if [ -n "$MINA_COMMIT_SHA1" ]; then
    # pull from env var if set
    id="$MINA_COMMIT_SHA1"
  else
    if [ ! -e .git ]; then echo 'Error: git repository not found'; exit 1; fi
    id=$(git rev-parse --verify HEAD)
    if [ -n "$(git diff --stat)" ]; then id="[DIRTY]$id"; fi
  fi
  commit_date=$(git show HEAD -s --format="%cI")
  pushd src/lib/crypto/proof-systems
    marlin_commit_id=$(git rev-parse --verify HEAD)
    if [ -n "$(git diff --stat)" ]; then marlin_commit_id="[DIRTY]$id"; fi
    marlin_commit_id_short=$(git rev-parse --short=8 --verify HEAD)
    marlin_commit_date=$(git show HEAD -s --format="%cI")
  popd
popd

{
    printf 'let commit_id = "%s"\n' "$id"
    printf 'let commit_id_short = "%s"\n' "$commit_id_short"
    printf 'let branch = "%s"\n' "$branch"
    printf 'let commit_date = "%s"\n' "$commit_date"

    printf 'let marlin_commit_id = "%s"\n' "$marlin_commit_id"
    printf 'let marlin_commit_id_short = "%s"\n' "$marlin_commit_id_short"
    printf 'let marlin_commit_date = "%s"\n' "$marlin_commit_date"

    printf 'let print_version () = Core_kernel.printf "Commit %%s on branch %%s\\n" commit_id branch\n'
} > "$1"

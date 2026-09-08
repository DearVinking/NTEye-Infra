#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resources/scripts/asset-allowlist.sh
source "$script_dir/asset-allowlist.sh"

baseline_commit="${1:?baseline commit is required}"
repository="${2:-https://github.com/Waifus-Grace/NTE_Assets.git}"
ref="${3:-HEAD}"

[[ "$baseline_commit" =~ ^[0-9a-fA-F]{40}$ ]] || {
  echo "baseline commit must be a 40-char sha: $baseline_commit" >&2
  exit 1
}

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

git init --quiet --bare "$workdir/git"
git -C "$workdir/git" remote add origin "$repository"
git -C "$workdir/git" config remote.origin.promisor true
git -C "$workdir/git" config remote.origin.partialclonefilter blob:none
git -C "$workdir/git" fetch --quiet --depth=1 --filter=blob:none origin "$ref"

head_commit="$(git -C "$workdir/git" rev-parse 'FETCH_HEAD^{commit}')"
echo "head_commit=$head_commit"

if [[ "$head_commit" == "$baseline_commit" ]]; then
  echo "changed=false"
  echo "reason=upstream HEAD unchanged ($head_commit)"
  exit 0
fi

if ! git -C "$workdir/git" fetch --quiet --depth=1 --filter=blob:none origin "$baseline_commit" 2>/dev/null; then
  echo "changed=true"
  echo "reason=baseline commit $baseline_commit is unreachable upstream (history rewritten), rebuilding to compare content"
  exit 0
fi

allowlisted_tree() {
  local commit="$1"
  git -C "$workdir/git" ls-tree -r --format='%(objectname) %(path)' "$commit" \
    | while IFS=' ' read -r object_name path; do
        asset_is_allowlisted "$path" && printf '%s %s\n' "$object_name" "$path"
      done \
    | LC_ALL=C sort -k2
}

if diff -q <(allowlisted_tree "$baseline_commit") <(allowlisted_tree "$head_commit") >/dev/null; then
  echo "changed=false"
  echo "reason=upstream moved to $head_commit but no allowlisted asset changed"
else
  changed_count="$(diff <(allowlisted_tree "$baseline_commit") <(allowlisted_tree "$head_commit") \
    | grep -cE '^[<>]' || true)"
  echo "changed=true"
  echo "reason=upstream moved to $head_commit with $changed_count allowlisted asset change(s)"
fi

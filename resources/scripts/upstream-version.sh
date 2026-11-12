#!/usr/bin/env bash
set -euo pipefail

repository="${1:?upstream repository is required}"
ref="${2:-HEAD}"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

git init --quiet --bare "$workdir/git"
git -C "$workdir/git" remote add origin "$repository"
git -C "$workdir/git" config remote.origin.promisor true
git -C "$workdir/git" config remote.origin.partialclonefilter tree:0
git -C "$workdir/git" fetch --quiet --depth=200 --filter=tree:0 origin "$ref"

head_commit="$(git -C "$workdir/git" rev-parse 'FETCH_HEAD^{commit}')"
echo "upstream_head_commit=$head_commit"

parse_subject_version() {
  local subject="$1"
  local major minor patch
  [[ "$subject" =~ ^[[:space:]]*[vV]?([0-9]+)\.([0-9]+)(\.([0-9]+))?([^0-9.]|$) ]] || return 1
  major=$((10#${BASH_REMATCH[1]}))
  minor=$((10#${BASH_REMATCH[2]}))
  if [[ -n "${BASH_REMATCH[4]:-}" ]]; then
    patch=$((10#${BASH_REMATCH[4]}))
  else
    patch=0
  fi
  printf '%s.%s.%s\n' "$major" "$minor" "$patch"
}

upstream_version=""
upstream_version_commit=""
upstream_version_subject=""

while IFS=' ' read -r commit subject; do
  if version="$(parse_subject_version "$subject")"; then
    upstream_version="$version"
    upstream_version_commit="$commit"
    upstream_version_subject="$subject"
    break
  fi
done < <(git -C "$workdir/git" log --format='%H %s' "$head_commit")

echo "upstream_version=$upstream_version"
echo "upstream_version_commit=$upstream_version_commit"
echo "upstream_version_subject=$upstream_version_subject"

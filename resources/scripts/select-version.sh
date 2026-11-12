#!/usr/bin/env bash
set -euo pipefail

baseline_version="${1:?baseline version is required}"
upstream_version="${2:-}"

[[ "$baseline_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "baseline version must be X.Y.Z: $baseline_version" >&2
  exit 1
}

version_key() {
  local major minor patch
  IFS=. read -r major minor patch <<<"$1"
  printf '%010d.%010d.%010d\n' "$((10#$major))" "$((10#$minor))" "$((10#$patch))"
}

highest_version="$baseline_version"
while IFS= read -r tag; do
  [[ "$tag" =~ ^resources-v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || continue
  version="${BASH_REMATCH[1]}"
  if [[ "$(version_key "$version")" > "$(version_key "$highest_version")" ]]; then
    highest_version="$version"
  fi
done

IFS=. read -r highest_major highest_minor highest_patch <<<"$highest_version"

next_version=""
version_source="patch"

if [[ "$upstream_version" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
  upstream_major=$((10#${BASH_REMATCH[1]}))
  upstream_minor=$((10#${BASH_REMATCH[2]}))
  if ((upstream_major > 10#$highest_major)) \
    || ((upstream_major == 10#$highest_major && upstream_minor > 10#$highest_minor)); then
    next_version="${upstream_major}.${upstream_minor}.0"
    version_source="upstream"
  fi
fi

if [[ -z "$next_version" ]]; then
  next_version="${highest_major}.${highest_minor}.$((10#$highest_patch + 1))"
  version_source="patch"
fi

echo "highest_version=$highest_version"
echo "next_version=$next_version"
echo "version_source=$version_source"

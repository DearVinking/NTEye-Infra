#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo="${1:?owner/repo is required}"
manifest_out="${2:-}"

tag_pattern='^resources-v([0-9]+)\.([0-9]+)\.([0-9]+)$'

version_sort_key() {
  local major minor patch
  IFS=. read -r major minor patch <<<"$1"
  printf '%010d.%010d.%010d\n' "$major" "$minor" "$patch"
}

mapfile -t released_versions < <(
  gh release list --repo "$repo" --limit 200 --exclude-drafts --json tagName \
    --jq '.[].tagName' \
    | sed -nE "s/$tag_pattern/\1.\2.\3/p"
)
if [[ ${#released_versions[@]} -eq 0 ]]; then
  echo "no published resources-v<X.Y.Z> release found in $repo;" \
    "publish the first version manually before enabling automatic checks" >&2
  exit 1
fi

baseline_version=""
baseline_key=""
for version in "${released_versions[@]}"; do
  key="$(version_sort_key "$version")"
  if [[ -z "$baseline_key" || "$key" > "$baseline_key" ]]; then
    baseline_key="$key"
    baseline_version="$version"
  fi
done
baseline_tag="resources-v${baseline_version}"

manifest="${manifest_out:-$(mktemp)}"
gh release download "$baseline_tag" --repo "$repo" \
  --pattern nteye-resources.json --output "$manifest" --clobber

manifest_version="$(jq -r '.manifest.version' "$manifest")"
if [[ "$manifest_version" != "$baseline_version" ]]; then
  echo "manifest version ($manifest_version) does not match tag $baseline_tag" >&2
  exit 1
fi

baseline_commit="$(jq -r '.manifest.source_commit' "$manifest")"
[[ "$baseline_commit" =~ ^[0-9a-fA-F]{40}$ ]] || {
  echo "manifest source_commit is not a 40-char sha: $baseline_commit" >&2
  exit 1
}
baseline_min_app_version="$(jq -r '.manifest.min_app_version' "$manifest")"
[[ "$baseline_min_app_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "manifest min_app_version is not X.Y.Z: $baseline_min_app_version" >&2
  exit 1
}

mapfile -t existing_tags < <(
  git ls-remote --tags "https://github.com/${repo}.git" \
    | sed -nE "s#^.*refs/tags/(resources-v[0-9]+\.[0-9]+\.[0-9]+)\$#\1#p"
)
tag_taken() {
  local candidate="$1" existing
  for existing in "${existing_tags[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  return 1
}

next_major="" next_minor="" next_patch=""
for tag in "${existing_tags[@]}" "$baseline_tag"; do
  version="${tag#resources-v}"
  IFS=. read -r major minor patch <<<"$version"
  key="$(version_sort_key "$version")"
  if [[ -z "$next_major" || "$key" > "$(version_sort_key "${next_major}.${next_minor}.${next_patch}")" ]]; then
    next_major="$major" next_minor="$minor" next_patch="$patch"
  fi
done

next_version=""
for _ in $(seq 1 100); do
  next_patch=$((next_patch + 1))
  candidate="${next_major}.${next_minor}.${next_patch}"
  if ! tag_taken "resources-v${candidate}"; then
    next_version="$candidate"
    break
  fi
done
[[ -n "$next_version" ]] || { echo "could not find an unused patch version" >&2; exit 1; }

echo "baseline_tag=$baseline_tag"
echo "baseline_version=$baseline_version"
echo "baseline_commit=$baseline_commit"
echo "baseline_min_app_version=$baseline_min_app_version"
echo "baseline_fingerprint=$(bash "$script_dir/manifest-fingerprint.sh" "$manifest")"
echo "next_version=$next_version"

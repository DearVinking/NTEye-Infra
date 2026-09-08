#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resources/scripts/asset-allowlist.sh
source "$script_dir/asset-allowlist.sh"

destination="${1:?destination is required}"
repository="${2:-https://github.com/Waifus-Grace/NTE_Assets.git}"
ref="${3:-HEAD}"

case "$destination" in
  ""|/*|*..*) echo "destination must be a new relative path" >&2; exit 1 ;;
esac
if [[ -e "$destination" ]]; then
  echo "destination already exists: $destination" >&2
  exit 1
fi
mkdir -p "$destination"
git clone --filter=blob:none --no-checkout --depth=1 "$repository" "$destination/git"

source_commit="$(git -C "$destination/git" rev-parse "${ref}^{commit}")"
printf '%s\n' "$source_commit" > "$destination/source-commit.txt"

while IFS= read -r path; do
  asset_is_allowlisted "$path" || continue
  mkdir -p "$destination/source/$(dirname "$path")"
  git -C "$destination/git" show "$source_commit:$path" > "$destination/source/$path"
done < <(git -C "$destination/git" ls-tree -r --name-only "$source_commit")

#!/usr/bin/env bash
set -euo pipefail

manifest="${1:?manifest path is required}"
[[ -f "$manifest" ]] || { echo "manifest not found: $manifest" >&2; exit 1; }

jq -e '.manifest.files | type == "array" and length > 0' "$manifest" >/dev/null

{
  jq -r '.manifest.map_schema_version' "$manifest"
  jq -r '.manifest.files | sort_by(.path)[] | "\(.path):\(.sha256)"' "$manifest"
} | sha256sum | cut -d' ' -f1

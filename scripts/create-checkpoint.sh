#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

purpose="${1:-}"
if [[ ! "$purpose" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Usage: $0 <short-purpose>" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit changes before creating a checkpoint." >&2
  exit 1
fi

upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [[ -z "$upstream" ]] || [[ "$(git rev-parse HEAD)" != "$(git rev-parse "$upstream")" ]]; then
  echo "Push the current commit to its upstream branch before creating a checkpoint." >&2
  exit 1
fi

./scripts/verify.sh

sha="$(git rev-parse --short HEAD)"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
tag="checkpoint/${purpose}/${timestamp}-${sha}"

git tag -a "$tag" -m "Verified checkpoint: $purpose at $sha"
git push origin "$tag"
echo "Created and pushed $tag"

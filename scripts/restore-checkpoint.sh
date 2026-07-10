#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before restoring." >&2
  exit 1
fi

checkpoint="${1:-$(git tag --list 'checkpoint/*' --sort=-creatordate | head -n 1)}"
if [[ -z "$checkpoint" ]]; then
  echo "No checkpoint tags exist yet." >&2
  exit 1
fi

if ! git rev-parse --verify --quiet "${checkpoint}^{commit}" >/dev/null; then
  echo "Unknown checkpoint or commit: $checkpoint" >&2
  exit 1
fi

short_sha="$(git rev-parse --short "$checkpoint")"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
branch="restore/${timestamp}-${short_sha}"

git switch -c "$branch" "$checkpoint"
echo "Created $branch at $checkpoint. Existing branches and commits were left untouched."

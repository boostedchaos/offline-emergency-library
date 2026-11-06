#!/usr/bin/env bash
# Rewrites SHA256SUMS.txt from the committed (HEAD) versions of the files it lists.
# Run by .github/workflows/sha256sums.yml on every push to main; PRs do not run it.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
: > SHA256SUMS.new
while read -r _ f; do
  f=${f%$'\r'}
  [ -z "$f" ] && continue
  h=$(git show "HEAD:$f" | sha256sum | cut -d' ' -f1)
  printf '%s  %s\n' "$h" "$f" >> SHA256SUMS.new
done < SHA256SUMS.txt
mv SHA256SUMS.new SHA256SUMS.txt

#!/usr/bin/env bash
# Prints the pending fragments in changelog.d/ as Added / Changed / Fixed sections.
# At release time: paste the output into CHANGELOG.md, then `git rm changelog.d/*.*.md`.
# Also run by CI, so a badly named fragment fails the PR that added it.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)/changelog.d"
shopt -s nullglob

for f in *; do
  case "$f" in
    README.md | *.added.md | *.changed.md | *.fixed.md) ;;
    *) echo "changelog.d/$f: name must be <slug>.added.md, <slug>.changed.md or <slug>.fixed.md" >&2; exit 1 ;;
  esac
done

for pair in added:Added changed:Changed fixed:Fixed; do
  files=(*."${pair%%:*}".md)
  [ ${#files[@]} -eq 0 ] && continue
  printf '### %s\n' "${pair##*:}"
  for f in "${files[@]}"; do
    cat "$f"
    [ -n "$(tail -c1 "$f")" ] && echo
  done
  echo
done

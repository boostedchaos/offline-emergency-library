#!/usr/bin/env bash
# Rebuild docs/*.html from docs/*.md (needs pandoc). Run from the repo root.
set -euo pipefail
cd "$(dirname "$0")/.."
css="$(cat tools/doc-style.css)"
for md in docs/*.md; do
  html="${md%.md}.html"
  title="$(grep -m1 '^# ' "$md" | sed 's/^# //')"
  body="$(pandoc -f gfm -t html5 "$md")"
  {
    printf '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
    printf '<meta name="viewport" content="width=device-width,initial-scale=1">'
    printf '<title>%s</title><style>%s</style></head><body><div class="wrap">\n' "$title" "$css"
    printf '%s\n' "$body"
    printf '</div></body></html>\n'
  } > "$html"
  echo "wrote $html"
done

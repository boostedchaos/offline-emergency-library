#!/usr/bin/env bash
# Scheduled source health: hashes deliberately fail when publisher text changes.
set -eu
cd "$(dirname "$0")/../.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0
while IFS=$'\t' read -r pdf algorithm pdfhash url texthash mode attribution; do
  case "$pdf" in ''|\#*) continue ;; esac
  if [[ ! "$texthash" =~ ^[a-f0-9]{64}$ ]]; then echo "FAIL: invalid text hash for $pdf"; fail=1; continue; fi
  case "$url" in
    text/*) path="doc-qa/$url" ;;
    https://archive.org/download/*)
      path="$tmp/$texthash.txt"
      # Archive's download nodes often time out or answer 5xx from CI runners, so only a
      # definite 4xx (item gone or moved) fails; a network outage is a warning, not a red PR.
      if ! code="$(curl -fLsS --connect-timeout 15 --max-time 90 --retry 3 --retry-all-errors --retry-delay 5 -w '%{http_code}' "$url" -o "$path")"; then
        case "$code" in
          4*) echo "FAIL: source gone (HTTP $code): $pdf"; fail=1 ;;
          *) item="${url#https://archive.org/download/}"; item="${item%%/*}"
             # An identifier that does not exist answers 503 here and {} on its metadata URL.
             if [ "$(curl -fsS --max-time 30 --retry 2 "https://archive.org/metadata/$item" 2>/dev/null)" = "{}" ]; then
               echo "FAIL: source gone (archive.org has no item $item): $pdf"; fail=1
             else echo "::warning::source unreachable (HTTP ${code:-none}), text not checked: $pdf"; fi ;;
        esac
        continue
      fi ;;
    *) echo "FAIL: unrecognized text URL for $pdf"; fail=1; continue ;;
  esac
  actual="$(sha256sum "$path" | cut -d' ' -f1)"
  if [ "$actual" = "$texthash" ]; then echo "PASS: $pdf"
  else echo "FAIL: source text changed: $pdf (review edition, extraction and license before updating)"; fail=1; fi
done < <(tr -d '\r' < doc-qa/sources.tsv)
exit "$fail"

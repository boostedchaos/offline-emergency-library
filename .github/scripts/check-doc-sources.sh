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
      # Archive's download nodes answer a transient 500 under load; retry before calling it down.
      if ! curl -fLsS --connect-timeout 15 --max-time 90 --retry 6 --retry-all-errors --retry-delay 5 "$url" -o "$path"; then
        echo "FAIL: source unavailable after retries: $pdf"; fail=1; continue
      fi ;;
    *) echo "FAIL: unrecognized text URL for $pdf"; fail=1; continue ;;
  esac
  actual="$(sha256sum "$path" | cut -d' ' -f1)"
  if [ "$actual" = "$texthash" ]; then echo "PASS: $pdf"
  else echo "FAIL: source text changed: $pdf (review edition, extraction and license before updating)"; fail=1; fi
done < <(tr -d '\r' < doc-qa/sources.tsv)
exit "$fail"

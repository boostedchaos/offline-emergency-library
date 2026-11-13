#!/usr/bin/env bash
# doc-qa allowlist coverage: every folder a sources.tsv PDF lives in must be allowed by BOTH
# manual-reader helpers (doc-qa/install.sh and doc-qa/install.ps1). When a content PR adds a new
# folder of PDFs to sources.tsv but forgets one allowlist, the reader setup errors on a fresh
# drive (bash "invalid PDF path", PowerShell "Unsafe document source manifest"). This catches it.
# The two allowlists must also agree with each other, and with the reader page's own list
# (pdfLink() in doc-qa/reader.mjs), which checks every ready.tsv row when the page loads.
# Needs bash and perl. Used by CI (lint job).
set -u
cd "$(dirname "$0")/../.." || exit 1
fail=0

# Folders used by sources.tsv PDF rows (column 1 is a repo-relative path; skip comments, blanks,
# and the non-PDF text/* rows that point at bundled page sources rather than a Manuals/ PDF).
src_folders="$(awk -F'\t' '$1 !~ /^#/ && $1 ~ /\.pdf$/ {sub(/\/[^\/]*$/,"",$1); print $1}' doc-qa/sources.tsv | sort -u)"
[ -n "$src_folders" ] || { echo "FAIL: could not read any PDF folder from doc-qa/sources.tsv"; exit 1; }

# Folders allowed by the bash helper: the case pattern "A/*.pdf|B/*.pdf) ".
sh_allow="$(grep -oE '[A-Za-z0-9_./-]+/\*\.pdf' doc-qa/install.sh | sed 's#/\*\.pdf$##' | sort -u)"

# Folders allowed by the PowerShell helper: the regex group ^(A|B|C)/ .
ps_allow="$(perl -ne 'if(/\^\(([^)]+)\)\/\[\^/){ print join("\n", split /\|/, $1), "\n" }' doc-qa/install.ps1 | sort -u)"

# Folders allowed by the reader page: the regex group /^(A\/B|C\/D)\/[^/ in pdfLink().
js_allow="$(perl -ne 'if(/function pdfLink/../^\}/){ if(/\^\(([^)]+)\)\\\/\[\^/){ (my $g=$1)=~s#\\/#/#g; print join("\n", split /\|/, $g), "\n" } }' doc-qa/reader.mjs | sort -u)"

[ -n "$sh_allow" ] || { echo "FAIL: could not read the bash allowlist from doc-qa/install.sh"; exit 1; }
[ -n "$ps_allow" ] || { echo "FAIL: could not read the PowerShell allowlist from doc-qa/install.ps1"; exit 1; }
[ -n "$js_allow" ] || { echo "FAIL: could not read the reader allowlist from pdfLink() in doc-qa/reader.mjs"; exit 1; }

# The two allowlists must match each other.
if [ "$sh_allow" != "$ps_allow" ]; then
  echo "FAIL: the bash and PowerShell doc-qa allowlists differ:"
  diff <(echo "$sh_allow") <(echo "$ps_allow") | sed 's/^/  /'
  fail=1
fi

# The reader page must allow the same folders, or one ready.tsv row outside its list stops the
# whole page ("Cannot load the manuals: Invalid PDF source path", #159).
if [ "$sh_allow" != "$js_allow" ]; then
  echo "FAIL: the reader allowlist (pdfLink() in doc-qa/reader.mjs) differs from doc-qa/install.sh:"
  diff <(echo "$sh_allow") <(echo "$js_allow") | sed 's/^/  /'
  fail=1
fi

# Every sources.tsv PDF folder must be in both allowlists.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$sh_allow" | grep -qxF "$f" || { echo "FAIL: '$f' (in sources.tsv) is not in the bash allowlist (doc-qa/install.sh)"; fail=1; }
  printf '%s\n' "$ps_allow" | grep -qxF "$f" || { echo "FAIL: '$f' (in sources.tsv) is not in the PowerShell allowlist (doc-qa/install.ps1)"; fail=1; }
done <<< "$src_folders"

if [ "$fail" = 0 ]; then
  echo "doc-qa allowlist OK: $(printf '%s' "$src_folders" | grep -c .) sources.tsv folders, all allowed by both helpers and the reader page."
else
  echo "Add the missing folder(s) to the allowlist in doc-qa/install.sh, doc-qa/install.ps1 and pdfLink() in doc-qa/reader.mjs."
  exit 1
fi

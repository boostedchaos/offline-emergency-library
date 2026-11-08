#!/usr/bin/env bash
# catalog.json (#139) lists the pieces a selection file can name, with their sizes. This check
# keeps it and both installers the same:
#   1. catalog.json is plain ASCII JSON; ids are unique and lower-case; every piece has a label
#      and a gb (null when the size is found at install time).
#   2. Both installers list the same ids, in the same order (SELECT_PIECES / $SelectPieces), and
#      the same pieces in each guided-install size preset (PRESET_* / $Preset*, #80).
#   3. Every size in catalog.json is the number both installers' space estimate uses.
#   4. Both installers accept every id with --select / -Selection (in --check-selection mode,
#      which stops before anything is created or downloaded) and print the same result; each
#      "needs" is enforced; bad files, an unknown id and mixed flags are refused with exit 1.
#      Each size preset is a valid selection too.
# Needs bash and pwsh. Used by CI (lint job). OEL_CATALOG=<file> checks another copy of the
# catalog (to prove this check fails on a bad one). OEL_PS=powershell.exe runs the PowerShell
# side with Windows PowerShell 5.1 (from Git Bash).
set -u
cd "$(dirname "$0")/../.." || exit 1
CAT="${OEL_CATALOG:-catalog.json}"
PS="${OEL_PS:-pwsh}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; bad(){ echo "FAIL: $*"; fail=1; }

# ---- 1. read catalog.json with a real JSON parser
cat > "$T/read.ps1" <<'EOF'
param($Path)
$ErrorActionPreference = 'Stop'
$raw = [IO.File]::ReadAllText($Path)
if($raw -match '[^\x09\x0A\x0D\x20-\x7E]'){ throw 'catalog.json must be plain ASCII' }
$c = $raw | ConvertFrom-Json
if($c.version -ne 1){ throw 'catalog.json: version must be 1' }
$inv = [cultureinfo]::InvariantCulture
$seen = @{}
$pieces = @($c.pieces)
foreach($p in $pieces){ if("$($p.id)" -cnotmatch '^[a-z0-9-]+$'){ throw "bad id '$($p.id)'" }; if($seen[$p.id]){ throw "duplicate id '$($p.id)'" }; $seen[$p.id] = 1 }
foreach($p in $pieces){
  if(-not $p.label -or "$($p.label)".Contains('|')){ throw "'$($p.id)' has no label" }
  if($p.PSObject.Properties.Name -cnotcontains 'gb'){ throw "'$($p.id)' has no gb (null when sized at install time)" }
  $needs = @($p.needs | Where-Object { $_ })
  foreach($n in $needs){ if(-not $seen[$n]){ throw "'$($p.id)' needs unknown id '$n'" } }
  $gb = if($null -eq $p.gb){ 'null' } else { ([double]$p.gb).ToString($inv) }
  $req = if($p.required){ 1 } else { 0 }
  "PIECE|$($p.id)|$gb|$($needs -join ' ')|$req|$($p.label)"
  $pre = @($p.presets | Where-Object { $_ })
  foreach($x in $pre){ if("$x" -cnotin 'small','standard','everything'){ throw "'$($p.id)' has unknown preset '$x'" } }
  "PRESETS|$($p.id)|$($pre -join ' ')"
  foreach($pr in $p.PSObject.Properties){   # every other number is a size constant (text fields are not checked here)
    $v = $pr.Value; $isNum = ($v -is [int]) -or ($v -is [long]) -or ($v -is [double]) -or ($v -is [decimal])
    if($isNum -and $pr.Name -cnotin 'id','required','needs','gb','label'){ "NUM|$($p.id)|$($pr.Name)|$(([double]$v).ToString($inv))" }
  }
}
EOF
"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$T/read.ps1" "$CAT" > "$T/cat.txt" 2>&1 || { cat "$T/cat.txt"; echo "FAIL: $CAT does not parse"; exit 1; }
tr -d '\r' < "$T/cat.txt" > "$T/cat.tsv"   # id|gb|needs|required|label ("|": a tab would let read merge empty fields)
ids="$(awk -F'|' '$1=="PIECE"{printf "%s ", $2}' "$T/cat.tsv" | sed 's/ $//')"
[ "$(echo "$ids" | wc -w | tr -d ' ')" -ge 5 ] || { cat "$T/cat.tsv"; echo "FAIL: too few pieces read from $CAT"; exit 1; }
echo "== catalog ids: $ids"

# ---- 2. the same ids, in the same order, in both installers
sh_ids="$(sed -n 's/^SELECT_PIECES="\(.*\)"$/\1/p' get-offline-library.sh)"
ps_ids="$(tr -d '\r' < Get-OfflineLibrary.ps1 | sed -n "s/^\$SelectPieces = \(.*\)$/\1/p" | tr -d "'" | tr ',' ' ')"
[ "$sh_ids" = "$ids" ] || bad "get-offline-library.sh SELECT_PIECES is '$sh_ids', catalog has '$ids'"
[ "$ps_ids" = "$ids" ] || bad "Get-OfflineLibrary.ps1 \$SelectPieces is '$ps_ids', catalog has '$ids'"
preset_ids(){ awk -F'|' -v p="$1" '$1=="PRESETS"{n=split($3,a," "); for(i=1;i<=n;i++) if(a[i]==p) printf "%s ", $2}' "$T/cat.tsv" | sed 's/ $//'; }
for pr in small:SMALL:Small standard:STANDARD:Standard everything:EVERYTHING:Everything; do
  name="${pr%%:*}"; rest="${pr#*:}"; want="$(preset_ids "$name")"
  sh_p="$(sed -n "s/^PRESET_${rest%%:*}=\"\(.*\)\"$/\1/p" get-offline-library.sh)"
  ps_p="$(tr -d '\r' < Get-OfflineLibrary.ps1 | sed -n "s/^\$Preset${rest#*:} = \(.*\)$/\1/p" | tr -d "'" | tr ',' ' ')"
  [ -n "$want" ] || bad "no piece in $CAT is in the '$name' preset"
  [ "$sh_p" = "$want" ] || bad "get-offline-library.sh PRESET_${rest%%:*} is '$sh_p', catalog '$name' preset has '$want'"
  [ "$ps_p" = "$want" ] || bad "Get-OfflineLibrary.ps1 \$Preset${rest#*:} is '$ps_p', catalog '$name' preset has '$want'"
  [ "$sh_p" = "$want" ] && [ "$ps_p" = "$want" ] && echo "  ok: preset $name = $want"
done

# ---- 3. every catalog size is the one the space estimates use
tr -d '\r' < Get-OfflineLibrary.ps1 > "$T/ps1.txt"
has1(){ # file text: the exact text is on exactly one line
  [ "$(grep -cF -- "$2" "$1")" = 1 ] && return 0
  bad "$(basename "$1"): expected one line with: $2"; return 1
}
while IFS='|' read -r kind id a b c label; do
  if [ "$kind" = PIECE ] && [ "$a" != null ]; then
    has1 get-offline-library.sh "est $a \"$label\"" && has1 "$T/ps1.txt" "\$est['$label'] = $a }" &&
      echo "  ok: $id $a GB in both estimates"
  elif [ "$kind" = NUM ]; then
    case "$id.$a" in
      maps.gb_viewer) has1 get-offline-library.sh "m/1024 + $b}" && has1 "$T/ps1.txt" "[math]::Round(\$mapGB + $b, 1)" ;;
      maps.gb_default_us) has1 get-offline-library.sh "GUIDE_US_GB=$b " && has1 "$T/ps1.txt" "\$GuideUsGB = $b " ;;
      browser-maps.gb_world_map) has1 get-offline-library.sh "b + $b}" && has1 "$T/ps1.txt" "[math]::Round(\$bm + $b, 1)" ;;
      browser-maps.gb_all_us) has1 get-offline-library.sh "all) bmgb=$b ;;" && has1 "$T/ps1.txt" "){ $b } elseif" ;;
      browser-maps.state_share_of_osmand) has1 get-offline-library.sh "print $b*m/1024}" && has1 "$T/ps1.txt" "{ $b * \$mapGB }" ;;
      *) bad "catalog field $id.$a: check-catalog.sh does not know where the installers use it. Add it here."; false ;;
    esac && echo "  ok: $id $a = $b in both estimates"
  fi
done < "$T/cat.tsv"
# the "choose less" hint names the two big skips, rounded
for pair in "wikipedia:skip-wikipedia:SkipWikipedia" "models:skip-models:SkipModels"; do
  id="${pair%%:*}"; rest="${pair#*:}"
  g="$(awk -F'|' -v i="$id" '$1=="PIECE" && $2==i{printf "%.0f", $3}' "$T/cat.tsv")"
  has1 get-offline-library.sh "--${rest%%:*} ($g GB)"; has1 "$T/ps1.txt" "-${rest#*:} ($g GB)"
done

# ---- 4. --select / -Selection in both installers (--check-selection: nothing is downloaded)
n=0
run(){ # name json [installer args, bash form] : runs both installers on the selection
  name="$1"; printf '%s' "$2" > "$T/$name.json"; shift 2
  sh_extra=""; ps_extra=""
  case "${1:-}" in
    only)   sh_extra="--only translate"; ps_extra="-Only translate" ;;
    lite)   sh_extra="--lite"; ps_extra="-Lite" ;;
    region) sh_extra="--region Gb"; ps_extra="-Region Gb" ;;
  esac
  # shellcheck disable=SC2086
  bash get-offline-library.sh --select "$T/$name.json" --check-selection -d "$T/dest" $sh_extra </dev/null > "$T/$name.sh" 2>&1; sh_rc=$?
  # shellcheck disable=SC2086
  "$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Get-OfflineLibrary.ps1 -Selection "$T/$name.json" -CheckSelection -Destination "$T/dest" $ps_extra </dev/null 2>&1 | tr -d '\r' > "$T/$name.ps"
  ps_rc="${PIPESTATUS[0]}"
  n=$((n+1))
}
show(){ echo "--- bash (exit $sh_rc):"; cat "$T/$name.sh"; echo "--- PowerShell (exit $ps_rc):"; cat "$T/$name.ps"; }
ok(){ # name json [expected Resolved: text]
  run "$1" "$2"
  if [ "$sh_rc" != 0 ] || [ "$ps_rc" != 0 ]; then bad "$1: a valid selection was refused: $2"; show; return; fi
  grep -E '^(Pieces|Regions|Resolved):' "$T/$name.sh" > "$T/$name.sh.r"; grep -E '^(Pieces|Regions|Resolved):' "$T/$name.ps" > "$T/$name.ps.r"
  [ "$(wc -l < "$T/$name.sh.r" | tr -d ' ')" = 3 ] || { bad "$1: bash did not print Pieces/Regions/Resolved"; show; return; }
  diff "$T/$name.sh.r" "$T/$name.ps.r" > /dev/null || { bad "$1: the installers read the selection differently: $2"; diff "$T/$name.sh.r" "$T/$name.ps.r"; return; }
  if [ -n "${3:-}" ]; then grep -qxF "Resolved: $3" "$T/$name.sh.r" || { bad "$1: expected 'Resolved: $3'"; show; return; }; fi
  echo "  ok: $1 -> $(sed -n 's/^Pieces: //p' "$T/$name.sh.r")"
}
no(){ # name text json [only|lite|region]: both installers exit 1 and say text
  run "$1" "$3" "${4:-}"
  if [ "$sh_rc" != 1 ] || [ "$ps_rc" != 1 ] || ! grep -qF -- "$2" "$T/$name.sh" || ! grep -qF -- "$2" "$T/$name.ps"; then
    bad "$1: expected exit 1 and '$2' from both installers: $3"; show; return
  fi
  echo "  ok: $1 refused ($2)"
}
q(){ printf '"%s",' "$@" | sed 's/,$//'; }   # ids -> "a","b"
needs_of(){ awk -F'|' -v i="$1" '$1=="PIECE" && $2==i{print $4}' "$T/cat.tsv"; }
uniq_words(){ out=""; for w in "$@"; do case " $out " in *" $w "*) ;; *) out="$out $w";; esac; done; echo $out; }

echo "== every catalog id is accepted (with what it needs)"
for id in $ids; do
  # shellcheck disable=SC2046
  set -- $(uniq_words core $(needs_of "$id") "$id")
  case " $* " in *" maps "*) r=',"regions":["US_delaware"]';; *) r="";; esac
  ok "id-$id" "{\"pieces\":[$(q "$@")]$r}"
done
echo "== each size preset (#80) is a valid selection"
for name in small standard everything; do
  # shellcheck disable=SC2046
  set -- $(preset_ids "$name")
  ok "preset-$name" "{\"pieces\":[$(q "$@")]}"
done
echo "== each 'needs' is enforced"
for id in $ids; do
  for need in $(needs_of "$id"); do
    # shellcheck disable=SC2046
    set -- $(uniq_words core $(needs_of "$id") "$id")
    keep=""; for w in "$@"; do [ "$w" = "$need" ] || keep="$keep $w"; done
    # shellcheck disable=SC2086
    no "needs-$id-$need" "'$need'" "{\"pieces\":[$(q $keep)]}"
  done
done
echo "== results and file shapes"
# shellcheck disable=SC2086
ok all "{\"pieces\":[$(q $ids)],\"regions\":[\"US_delaware\",\"Gb\"]}" \
  "lite=0 skip-models=0 skip-wikipedia=0 skip-maps=0 region=US_delaware,Gb browser-maps=1 education=1 kolibri=1 extra-zims=1 translate=1 medlineplus=1"
ok core-only '{"pieces":["core"]}' \
  "lite=1 skip-models=1 skip-wikipedia=1 skip-maps=1 region=- browser-maps=0 education=0 kolibri=0 extra-zims=0 translate=0 medlineplus=0"
ok maps-default-us '{"pieces":["core","gpt4all-repair","maps"]}' \
  "lite=0 skip-models=1 skip-wikipedia=1 skip-maps=0 region=US browser-maps=0 education=0 kolibri=0 extra-zims=0 translate=0 medlineplus=0"
ok pretty-bom "$(printf '\357\273\277{\r\n  "regions": [ "US_delaware" ],\r\n\t"pieces": [\r\n    "core",\r\n    "maps"\r\n  ]\r\n}\r\n')"
[ ! -e "$T/dest" ] || bad "--check-selection created the destination folder"
no unknown-id "unknown piece 'bogus'" '{"pieces":["core","bogus"]}'
no upper-case-id "unknown piece 'Core'" '{"pieces":["Core"]}'
no no-core "'core' is always installed" '{"pieces":["maps"]}'
no regions-no-maps "lists regions but not 'maps'" '{"pieces":["core"],"regions":["Gb"]}'
no empty "names no pieces" '{"pieces":[]}'
for s in '{"pieces":["core"],"extra":["x"]}' '{"pieces":["core",]}' '{"pieces":"core"}' '{"pieces":[{"id":"core"}]}' \
         "{'pieces':['core']}" '{"regions":["Gb"]}' '{"Pieces":["core"]}' '{"pieces":["core"],"pieces":["maps"]}' \
         '{"pieces":["core"]}x' '{"pieces":["co re"]}' '{"pieces":["core"]} {}' 'core maps' ''; do
  no "shape-$n" "is not a selection file" "$s"
done
no with-only "cannot be combined with" '{"pieces":["core"]}' only
no with-lite "cannot be combined with" '{"pieces":["core"]}' lite
no with-region "cannot be combined with" '{"pieces":["core","maps"]}' region
rm -f "$T/missing.json"
sh_rc=0; out="$(bash get-offline-library.sh --select "$T/missing.json" --check-selection </dev/null 2>&1)" || sh_rc=$?
ps_out="$("$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Get-OfflineLibrary.ps1 -Selection "$T/missing.json" -CheckSelection </dev/null 2>&1)"; ps_rc=$?
case "$sh_rc $ps_rc $out $ps_out" in "1 1 "*"selection file not found"*"selection file not found"*) echo "  ok: missing file refused";; *) bad "missing file: bash $sh_rc '$out' / PowerShell $ps_rc '$ps_out'";; esac
# --select followed by another flag must not swallow the flag as the file name (#167)
sh_rc=0; out="$(bash get-offline-library.sh --select --check-selection </dev/null 2>&1)" || sh_rc=$?
ps_out="$("$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Get-OfflineLibrary.ps1 -Selection -CheckSelection </dev/null 2>&1)"; ps_rc=$?
if [ "$sh_rc" = 1 ] && printf '%s' "$out" | grep -qF -- "--select needs a selection file" && [ "$ps_rc" != 0 ]; then
  echo "  ok: --select with no file refused (bash) / rejected at binding (PowerShell)"
else bad "--select no file: bash $sh_rc '$out' / PowerShell $ps_rc '$ps_out'"; fi
# A UTF-16 selection file must be refused by both, not silently accepted by one (#167)
if command -v iconv >/dev/null 2>&1; then
  printf '{"pieces":["core"]}' | iconv -f UTF-8 -t UTF-16 > "$T/utf16.json"
  sh_rc=0; out="$(bash get-offline-library.sh --select "$T/utf16.json" --check-selection </dev/null 2>&1)" || sh_rc=$?
  ps_out="$("$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Get-OfflineLibrary.ps1 -Selection "$T/utf16.json" -CheckSelection </dev/null 2>&1)"; ps_rc=$?
  if [ "$sh_rc" = 1 ] && [ "$ps_rc" = 1 ] && printf '%s' "$out" | grep -qiF "UTF-16" && printf '%s' "$ps_out" | grep -qiF "UTF-16"; then
    echo "  ok: UTF-16 selection refused by both (with the save-as-UTF-8 hint)"
  else bad "UTF-16: bash $sh_rc '$out' / PowerShell $ps_rc '$ps_out'"; fi
else echo "  (skip UTF-16 case: iconv not available)"; fi
sh_rc=0; out="$(bash get-offline-library.sh --check-selection </dev/null 2>&1)" || sh_rc=$?
ps_out="$("$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Get-OfflineLibrary.ps1 -CheckSelection </dev/null 2>&1)"; ps_rc=$?
case "$sh_rc $ps_rc $out $ps_out" in "1 1 "*"needs"*"needs"*) echo "  ok: --check-selection alone refused";; *) bad "--check-selection alone: bash $sh_rc '$out' / PowerShell $ps_rc '$ps_out'";; esac

echo "== $n selection files run through both installers"
[ "$fail" = 0 ] && echo "Catalog check: OK" || { echo "Catalog check: FAILED - keep catalog.json and both installers the same."; exit 1; }

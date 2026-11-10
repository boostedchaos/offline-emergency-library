#!/usr/bin/env bash
# Region tokens pick the same OsmAnd maps in both installers. Runs each installer's own alias
# table and --region / -Region match lines on a small offline index:
#   - Australia (and aus) picks the Australian state maps: OsmAnd has no Australia_* map, it files
#     Australia by state as Australia-oceania_<state>_*.obf.zip.
#   - australia-oceania (any case) is still the whole continent.
#   - Oceania is a name prefix, not part of the continent name (bash grep -w took it as one).
#   - A <deleted_map> entry is not a map: OsmAnd answers 404 for it (#231).
# Needs bash and pwsh. OEL_PS=powershell.exe runs the PowerShell side with Windows PowerShell 5.1.
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO="$PWD"
PS="${OEL_PS:-pwsh}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; bad(){ echo "FAIL: $*"; fail=1; }

cat > "$T/index.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osmand_regions>
<region type="map" containerSize="1048576" name="Australia-oceania_tasmania_australia-oceania_2.obf.zip"/>
<region type="map" containerSize="1048576" name="Australia-oceania_victoria_australia-oceania_2.obf.zip"/>
<region type="map" containerSize="1048576" name="New-zealand_australia-oceania_2.obf.zip"/>
<region type="map" containerSize="1048576" name="Oceania_australia-oceania_2.obf.zip"/>
<region type="map" containerSize="1048576" name="Papua-new-guinea_australia-oceania_2.obf.zip"/>
<region type="map" containerSize="1048576" name="Belgium_flanders_europe_2.obf.zip"/>
<deleted_map type="deleted_map" date="06.07.2026" size="" targetsize="" containerSize="0" contentSize="0" free="false" name="Belgium_europe_2.obf.zip" timestamp="1793919600000"/>
<region type="map" containerSize="1048576" name="Us_delaware_northamerica_2.obf.zip"/>
</osmand_regions>
EOF
AUS="Australia-oceania_tasmania_australia-oceania_2.obf.zip Australia-oceania_victoria_australia-oceania_2.obf.zip"
CONT="$AUS New-zealand_australia-oceania_2.obf.zip Oceania_australia-oceania_2.obf.zip Papua-new-guinea_australia-oceania_2.obf.zip"
# token|expected maps (sorted, space separated)
cases="Australia|$AUS
aus|$AUS
australia-oceania|$CONT
Australia-Oceania|$CONT
Oceania|Oceania_australia-oceania_2.obf.zip
New-Zealand|New-zealand_australia-oceania_2.obf.zip
Belgium|Belgium_flanders_europe_2.obf.zip
US_delaware|Us_delaware_northamerica_2.obf.zip"

# ---- bash: the installer's CONTINENTS, alias_region and map lookup section
sed -n '/^CONTINENTS=/p; /^alias_region(){/,/^}/p' get-offline-library.sh > "$T/alias.sh"
sed -n '/^# ---- OsmAnd map files/,/^# ---- space estimate/p' get-offline-library.sh > "$T/lookup.sh"
grep -q '^alias_region' "$T/alias.sh" && [ -s "$T/lookup.sh" ] || { echo "FAIL: region code not found in get-offline-library.sh"; exit 1; }
sh_maps(){ # token -> sorted map names, one line
  (
    curl(){ local out="" a; while [ "$#" -gt 0 ]; do a="$1"; shift; [ "$a" = -o ] && { out="$1"; shift; }; done; cp "$T/index.xml" "$out"; }
    log(){ :; }
    . "$T/alias.sh"
    ROOT="$T/sh"; SKIP_MAPS=0; BM_ONLY=0; REGION="$1"
    . "$T/lookup.sh"
    sort "$ROOT/OsmAnd/_filelist.txt" | tr '\n' ' ' | sed 's/ $//'
  ) 2>/dev/null
}

# ---- PowerShell: the installer's $Continents, alias table and -Region match lines
cat > "$T/regions.ps1" <<'EOF'
param($Installer, $Index, $Tokens)
$ErrorActionPreference = 'Stop'
$src = Get-Content -LiteralPath $Installer
function At($s){ $n = ($src | Select-String -SimpleMatch $s | Select-Object -First 1).LineNumber; if(-not $n){ throw "not found in installer: $s" }; $n }
$a = At '$Continents = @('; $b = At 'function Resolve-RegionToken'
$c = At '$tokens = ($Region -split'; $d = At '$sel = @($sel | Sort-Object name -Unique)'
Invoke-Expression (($src[($a-1)..($b-1)]) -join "`n")
$block = ($src[($c-1)..($d-1)]) -join "`n"
[xml]$idx = Get-Content -LiteralPath $Index
$allmaps = $idx.osmand_regions.region | Where-Object { $_.type -eq 'map' }
foreach($Region in ($Tokens -split ',')){
  $sel = @()
  Invoke-Expression $block
  $Region + '|' + ((@($sel | ForEach-Object { $_.name }) | Sort-Object) -join ' ')
}
EOF
toks="$(printf '%s\n' "$cases" | cut -d'|' -f1 | paste -sd, -)"
"$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$T/regions.ps1" "$REPO/Get-OfflineLibrary.ps1" "$T/index.xml" "$toks" 2>&1 | tr -d '\r' > "$T/ps.txt" ||
  { cat "$T/ps.txt"; echo "FAIL: PowerShell region code did not run"; exit 1; }

while IFS='|' read -r tok want; do
  got="$(sh_maps "$tok")"
  [ "$got" = "$want" ] && echo "PASS: bash '$tok'" || bad "bash '$tok' picked [$got], want [$want]"
  got="$(grep -m1 "^$tok|" "$T/ps.txt" | cut -d'|' -f2)"
  [ "$got" = "$want" ] && echo "PASS: PowerShell '$tok'" || bad "PowerShell '$tok' picked [$got], want [$want]"
done <<EOF
$cases
EOF
exit "$fail"

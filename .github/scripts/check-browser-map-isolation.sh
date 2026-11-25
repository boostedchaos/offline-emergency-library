#!/usr/bin/env bash
# Issue #125: run the real --only CLI with offline download fixtures.
set -eu
cd "$(dirname "$0")/../.."
REPO="$PWD"
T="$(mktemp -d)"
trap 'rm -rf "$T"; test ! -e "$T" && echo "CLEANUP: removed $T"' EXIT
die(){ echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$T/assets/tozip" "$T/tmp"
echo '{}' > "$T/assets/tozip/nomad-base-styles.json"
tar -czf "$T/assets.tar.gz" -C "$T/assets" tozip
export OEL_FIXTURES="$T"
cat > "$T/network.sh" <<'EOS'
sleep(){ :; }   # no pause between get_small's tries (#302)
curl(){
  local out="" url="" arg
  while [ "$#" -gt 0 ]; do
    arg="$1"; shift
    case "$arg" in
      -o) out="$1"; shift ;;
      -H|-A|--retry|--retry-delay|-C) shift ;;
      https://*) url="$arg" ;;
    esac
  done
  case "$url" in
    */commits/main) printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' ;;
    *get_indexes)
      [ -z "${OEL_NO_INDEX:-}" ] || return 22
      printf '<region containerSize="1073741824" name="Us_delaware_northamerica_2.obf.zip"/>\n' > "$out" ;;
    */contents/pmtiles)
      printf '[{"name":"global_2026-01.pmtiles"},{"name":"delaware_2026-01.pmtiles"},{"name":"texas_2026-01.pmtiles"}]\n' ;;
    */releases/latest) echo '{}' ;;
    */base-assets.tar.gz)
      [ -z "$out" ] || cp "$OEL_FIXTURES/assets.tar.gz" "$out" ;;
    *.pmtiles) printf 'PMTiles fixture' > "$out" ;;
    https://unpkg.com/*) echo 'maplibregl pmtiles' > "$out" ;;
    *) echo "Unexpected fixture URL: $url" >&2; return 1 ;;
  esac
}
EOS

for mode in existing absent; do
  DEST="$T/$mode drive"; ROOT="$DEST/OfflineLibrary"
  mkdir -p "$ROOT/AI-Offline/engine"
  echo fixture > "$ROOT/AI-Offline/engine/BUILD.txt"
  for platform in x64 arm64 vulkan-x64 macos-arm64 macos-x64 linux-x64 linux-arm64 linux-vulkan-x64; do
    mkdir -p "$ROOT/AI-Offline/engine/$platform"
    case "$platform" in x64|arm64|vulkan-x64) bin=llama-cli.exe ;; *) bin=llama-cli ;; esac
    printf '#!/usr/bin/env bash\necho "version: fixture"\n' > "$ROOT/AI-Offline/engine/$platform/$bin"
    chmod +x "$ROOT/AI-Offline/engine/$platform/$bin"
  done
  # A file --only browser-maps does not touch (its line must be kept) and one that is gone (#195).
  Z=0000000000000000000000000000000000000000000000000000000000000000
  printf '%s  %s\n' "$Z" ./AI-Offline/engine/BUILD.txt "$Z" ./gone.txt "$Z" ./README.html > "$ROOT/CHECKSUMS-SHA256.txt"
  # A finished drive already has the shared index and drive-check launchers.
  for file in CHECK-DRIVE.bat CHECK-DRIVE.command CHECK-DRIVE.sh README.html check-drive.ps1; do
    echo 'existing generated file' > "$ROOT/$file"
  done
  if [ "$mode" = existing ]; then
    mkdir -p "$ROOT/OsmAnd"
    echo 'previous Texas index' > "$ROOT/OsmAnd/_index.xml"
    echo 'Us_texas_northamerica_2.obf.zip' > "$ROOT/OsmAnd/_filelist.txt"
    cp -R "$ROOT/OsmAnd" "$T/original-osmand"
  fi
  (cd "$ROOT" && find . -type f | LC_ALL=C sort) > "$T/before"
  # Only the network boundary is replaced; flags, downloads, selection and writes are real.
  BASH_ENV="$T/network.sh" TMPDIR="$T/tmp" bash "$REPO/get-offline-library.sh" \
    --only browser-maps --region US_delaware --no-aria -d "$DEST" > "$T/$mode.log" 2>&1 ||
    { cat "$T/$mode.log"; die "$mode installer failed"; }
  if [ "$mode" = existing ]; then
    diff -r "$T/original-osmand" "$ROOT/OsmAnd" || die "existing OsmAnd metadata changed"
  else
    [ ! -e "$ROOT/OsmAnd" ] || die "browser-only addition created OsmAnd"
  fi
  [ -s "$ROOT/Maps-Browser/pmtiles/delaware_2026-01.pmtiles" ] || die "Delaware map missing"
  [ -s "$ROOT/Maps-Browser/pmtiles/global_2026-01.pmtiles" ] || die "world map missing"
  [ ! -e "$ROOT/Maps-Browser/pmtiles/texas_2026-01.pmtiles" ] || die "wrong state selected"
  grep -q '0.6 GB  browser maps' "$T/$mode.log" || die "region size estimate lost"
  (cd "$ROOT" && find . -type f | LC_ALL=C sort) > "$T/after"
  added="$(comm -13 "$T/before" "$T/after" | grep -vE '^\./(Maps-Browser/|_download\.log$)' || true)"
  [ -z "$added" ] || die "unrelated added files: $added"
  [ -z "$(ls -A "$T/tmp")" ] || die "lookup temp files leaked"
  grep -q 'Repo files: commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$T/$mode.log" || die "repo files not pinned to the commit (#193)"
  S="$ROOT/CHECKSUMS-SHA256.txt"
  grep -qxF "$Z  ./AI-Offline/engine/BUILD.txt" "$S" || die "--only re-hashed a file it did not write (#195)"
  grep -qF ./gone.txt "$S" && die "--only kept the line of a file that is gone (#195)"
  grep -qF "$Z  ./README.html" "$S" && die "--only did not re-hash README.html (#195)"
  grep -qE '^[0-9a-f]{64}  \./Maps-Browser/pmtiles/delaware_2026-01\.pmtiles$' "$S" || die "--only did not hash its new map (#195)"
  echo "PASS: $mode OsmAnd isolated; selected maps installed; estimate retained; temp files removed; checksum list updated in place"
done

# A region with no maps, or no map index, stops before any download (#192).
for case_ in "Frnace|no maps matched region 'Frnace'|" "US|could not read the OsmAnd map index|1"; do
  IFS='|' read -r region want noidx <<< "$case_"
  DEST="$T/nomatch"; rm -rf "$DEST"
  OEL_NO_INDEX="$noidx" BASH_ENV="$T/network.sh" TMPDIR="$T/tmp" bash "$REPO/get-offline-library.sh" \
    --region "$region" --skip-wikipedia --no-aria -d "$DEST" > "$T/nomatch.log" 2>&1 </dev/null && { cat "$T/nomatch.log"; die "region '$region' did not stop"; }
  grep -qF "$want" "$T/nomatch.log" || { cat "$T/nomatch.log"; die "region '$region': expected '$want'"; }
  grep -q 'Unexpected fixture URL' "$T/nomatch.log" && { cat "$T/nomatch.log"; die "region '$region': downloaded before stopping"; }
  echo "PASS: region '$region' stops before downloading: $want"
done

# The normal install still needs its persistent lookup for later OsmAnd downloads.
sed -n -e '/^get_small()/,/^}/p' -e '/^# ---- OsmAnd map files/,/^# ---- space estimate/p' get-offline-library.sh > "$T/lookup.sh"
[ -s "$T/lookup.sh" ] || die "region lookup section missing"
(
  . "$T/network.sh"
  ROOT="$T/normal"; SKIP_MAPS=0; BM_ONLY=0; REGION=US_delaware
  CONTINENTS="northamerica"
  alias_region(){ echo "$1"; }
  . "$T/lookup.sh"
  [ "$MAP_MB" = 1024 ] || die "normal map size changed"
  [ "$(cat "$ROOT/OsmAnd/_filelist.txt")" = Us_delaware_northamerica_2.obf.zip ] ||
    die "normal map selection changed"
  [ -s "$ROOT/OsmAnd/_index.xml" ] || die "normal index missing"
)
echo "PASS: normal install retains OsmAnd index, selection and size"

#!/usr/bin/env bash
# Per-OS smoke test with a portability check (#69), macOS and Linux half
# (check-smoke.ps1 is the Windows half). No models, ZIMs or maps are downloaded.
#
# Runs the real engine, launcher, CHECK-DRIVE and checksum sections of
# get-offline-library.sh into a temp folder, downloading only the engine for THIS computer.
# The installer still picks the llama.cpp build the real way (a build that has the files for
# all 8 platforms), so a missing file for any OS fails the run. Then it moves the folder to
# a new path and, from there: scans every file for the old path, runs each launcher with
# --version, and runs CHECK-DRIVE.
# Needs bash, curl, tar, awk. Set GITHUB_TOKEN to avoid the API rate limit. Used by CI (smoke job).
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO="$PWD"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
die(){ echo "FAIL: $*"; exit 1; }

# What this computer must end up with, written down here and not read from the installer,
# so that a wrong folder name in the installer shows up as a failure.
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  ASSET="ubuntu-x64.tar.gz:linux-x64";;
  Darwin-arm64)  ASSET="macos-arm64.tar.gz:macos-arm64";;
  *) die "no expected engine for $(uname -s)-$(uname -m): add it to this script";;
esac
WANT_DIR="${ASSET##*:}"

# ---- the installer's own code, cut out by its section markers ----
# need FILE MIN_LINES: both ends of a section must be found, or sed runs on to the end of the file.
need(){ n=$(grep -c . "$1"); [ "$n" -ge "$2" ] || die "section not found in get-offline-library.sh ($(basename "$1"): $n lines). Were its markers renamed?"; }
sed -n '/^# =* 1\. AI engine/,/^# =* 2\. AI models/p' get-offline-library.sh \
  | awk '/^    E="\$ROOT\/AI-Offline\/engine"$/{print; getline; if(sub(/\$LLAMA_ASSETS/,"$SMOKE_ASSETS")) n++} {print} END{if(n!=1) exit 3}' > "$T/engine.sh" \
  || die "engine section: the download loop was not found. Was it renamed?"
need "$T/engine.sh" 20
sed -n '/^AO="\$ROOT\/AI-Offline"/,/^# =* documentation/p' get-offline-library.sh > "$T/launchers.sh"; need "$T/launchers.sh" 20
sed -n '/^# CHECK-DRIVE scripts/,/^chmod +x "[$]ROOT\/CHECK-DRIVE.sh"/p' get-offline-library.sh > "$T/checkdrive.sh"; need "$T/checkdrive.sh" 5
sed -n '/^# =* drive check (#28)/,/^# =* self-check/p' get-offline-library.sh > "$T/sums.sh"; need "$T/sums.sh" 10

# ---- the installer's helpers, replaced: log, a plain downloader, and a token for the GitHub API ----
SMOKE_ASSETS="$ASSET"
log(){ echo "  $*"; }
fetch(){ command curl -fL --retry 5 --retry-delay 5 -sS -o "$2" "$1" && [ -s "$2" ] || { echo "download failed: $1"; exit 1; }; }
curl(){
  case "$*" in
    *api.github.com*) [ -n "${GITHUB_TOKEN:-}" ] && { command curl -H "Authorization: Bearer $GITHUB_TOKEN" "$@"; return; };;
  esac
  command curl "$@"
}

ORIG="$T/oel-smoke-original"; ROOT="$ORIG/OfflineLibrary"
mkdir -p "$ROOT/AI-Offline/engine"
echo "== build the drive at $ROOT (engine for $WANT_DIR only)"
( HAVE_TAR=1; HAVE_UNZIP=1; . "$T/engine.sh" ) || die "the installer's engine section stopped with an error"
E="$ROOT/AI-Offline/engine"
[ -s "$E/BUILD.txt" ] || die "no llama.cpp build was picked: none of the recent releases has the files for all 8 platforms (see the engine: line above)"
TAG="$(tr -d ' \r\n' < "$E/BUILD.txt")"
[ -n "$(find "$E/$WANT_DIR" -name llama-cli -type f 2>/dev/null | head -n1)" ] || die "build $TAG has no llama-cli in engine/$WANT_DIR"
( set +u; LITE=1; TRANSLATE=0; . "$T/launchers.sh" ) || die "the installer's launcher section stopped with an error"
[ -z "$(find "$ROOT/AI-Offline" -iname '*translat*')" ] || die "translator files were written without --translate"
eval "$(grep -m1 '^TR_MODEL=' get-offline-library.sh)"
( set +u; LITE=1; TRANSLATE=1; . "$T/launchers.sh" ) || die "the installer's translator launcher section stopped with an error"
( set +u; SCRIPTDIR="$REPO"; UA=Mozilla/5.0; . "$T/checkdrive.sh" ) || die "the installer's CHECK-DRIVE section stopped with an error"
( set +u; . "$T/sums.sh" ) || die "the installer's checksum section stopped with an error"
ls "$ROOT/AI-Offline"/*.sh >/dev/null 2>&1 || die "no .sh launcher was written"

echo "== every engine folder a launcher can pick is one the installer fills"
eval "$(grep -m1 '^LLAMA_ASSETS=' "$T/engine.sh")"
dirs=" $(for x in $LLAMA_ASSETS; do printf '%s ' "${x##*:}"; done)"
picks="$( { grep -oE ' P=[a-z0-9-]+' "$T/launchers.sh" | sed 's/^ P=//'; grep -oE 'engine\\[a-z0-9-]+\\' "$T/launchers.sh" | sed -E 's/^engine\\//; s/\\$//'; } | sort -u)"
[ "$(echo "$picks" | grep -c .)" -ge 5 ] || die "found only: $picks (launcher section changed shape?)"
for p in $picks; do case "$dirs" in *" $p "*) echo "  ok: $p";; *) die "a launcher picks engine/$p, but the installer has no such folder (folders: $dirs)";; esac; done

echo "== move the drive to a new path, and remove the old one"
NEW="$T/moved here/Library copy"
mkdir -p "$T/moved here" && mv "$ROOT" "$NEW" && rm -rf "$ORIG" || die "could not move the folder"

echo "== no file may name the old path"
hits(){ grep -rlF "oel-smoke-original" "$NEW" 2>/dev/null; }
echo "oel-smoke-original" > "$NEW/_probe.txt"; hits | grep -qxF "$NEW/_probe.txt" || die "self-test of the path scan failed"; rm -f "$NEW/_probe.txt"
h="$(hits)"; [ -z "$h" ] || die "these files contain the old path:
$h"
echo "  none"

echo "== launchers run from the new path (--version)"
for s in "$NEW/AI-Offline"/*.sh; do
  [ "$(basename "$s")" = translate-browser.sh ] && continue
  c="$NEW/AI-Offline/_smoke-$(basename "$s")"
  sed 's|^exec "\$BIN" |exec "$BIN" --version |' "$s" > "$c"
  [ "$(grep -c -- '--version' "$c")" = 1 ] || die "$(basename "$s"): its last line is not 'exec \"\$BIN\" ...' any more"
  out="$(bash "$c" </dev/null 2>&1)"; rc=$?
  rm -f "$c"
  [ "$rc" = 0 ] || die "$(basename "$s") exited $rc:
$out"
  # Older builds print "version: 6234 (abc)", newer ones "version: 0.9.0-dev (build 12128, commit abc)".
  v="$(echo "$out" | grep -m1 -E "version: .*[^0-9]${TAG#b}[^0-9]")" || die "$(basename "$s") did not report build $TAG:
$out"
  echo "  ok: $(basename "$s"): $v"
done

echo "== generated browser launcher rejects missing and invalid models without opening a browser"
mkdir -p "$T/browser-bin" "$NEW/AI-Offline/models"
printf '#!/usr/bin/env bash\necho UNEXPECTED_BROWSER_OPEN\n' > "$T/browser-bin/open"
cp "$T/browser-bin/open" "$T/browser-bin/xdg-open"; chmod +x "$T/browser-bin/"*
out="$(PATH="$T/browser-bin:$PATH" bash "$NEW/AI-Offline/translate-browser.sh" </dev/null 2>&1)"; rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q 'Translator model missing' || die "missing translator model (exit $rc): $out"
printf 'not a GGUF model\n' > "$NEW/AI-Offline/models/$TR_MODEL"
out="$(PATH="$T/browser-bin:$PATH" bash "$NEW/AI-Offline/translate-browser.sh" </dev/null 2>&1)"; rc=$?
rm -f "$NEW/AI-Offline/models/$TR_MODEL"
[ "$rc" = 1 ] && echo "$out" | grep -q 'Translator did not start' || die "invalid translator model (exit $rc): $out"
echo "$out" | grep -q 'UNEXPECTED_BROWSER_OPEN' && die "failed translator opened the browser"

echo "== CHECK-DRIVE from the new path"
for c in CHECK-DRIVE.sh CHECK-DRIVE.command; do
  out="$(bash "$NEW/$c" </dev/null 2>&1)"; rc=$?
  [ "$rc" = 0 ] && echo "$out" | grep -qE 'RESULT: ALL [1-9][0-9]* FILES OK' || die "$c failed (exit $rc):
$out"
  echo "  ok: $c: $(echo "$out" | grep -m1 RESULT)"
done
echo "== --only (#74) stops with a plain message before it downloads or creates anything"
O="$T/only-test"
chk(){ # text args...: the installer must exit 1 and say text
  want="$1"; shift
  out="$(bash get-offline-library.sh "$@" 2>&1 </dev/null)"; rc=$?
  [ "$rc" = 1 ] && printf '%s' "$out" | grep -qF -- "$want" || die "get-offline-library.sh $*: expected exit 1 and '$want', got exit $rc:
$out"
  echo "  ok: $*"
}
chk "needs at least one piece" --only -d "$O"
chk "unknown piece" --only bogus -d "$O"
chk "cannot be combined" --only translate --lite -d "$O"
chk "no finished library" --only translate -d "$O"
[ ! -e "$O" ] || die "--only created $O although there was no finished library there"
mkdir -p "$O/OfflineLibrary"; echo "x  ./a" > "$O/OfflineLibrary/CHECKSUMS-SHA256.txt"
chk "needs the AI engine" --only translate -d "$O"
[ "$(find "$O" -type f | wc -l | tr -d ' ')" = 1 ] || die "--only translate wrote files although the AI engine is missing"
echo "Smoke test: OK ($(uname -s) $(uname -m), llama.cpp $TAG)"

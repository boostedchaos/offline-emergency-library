#!/usr/bin/env bash
# get-offline-library.sh - Mac/Linux downloader for the Offline Emergency Library.
# Mirrors Get-OfflineLibrary.ps1. Resumable: run it again to continue or to update.
#
# Usage:
#   ./get-offline-library.sh                       # asks where to save
#   ./get-offline-library.sh -d /Volumes/MyDrive   # no questions
#   ./get-offline-library.sh --dry-run             # check every link + total size, download nothing
# Options:
#   --wikipedia maxi|nopic|mini|none   which Wikipedia (default: nopic = all articles, no images)
#   --skip-groups a,b                  skip content groups: medicine,survival,diy,food,education,computing,pdfs
#   --skip-wikipedia  --skip-maps  --skip-models (small AI model only)  --skip-ai
#   --map-regions a,b                  only these US states in both map types, e.g. "texas,new mexico"
#   --catalog FILE                     use another ZIM list (default: catalog/zims.tsv)
#   --jobs N                           archives downloaded at the same time (default 4; 2 with aria2)
# Faster: install aria2 (brew install aria2 / apt install aria2). Then each archive is
# downloaded in many pieces from several Kiwix mirrors at once, and checked by aria2.

REPO_RAW="https://raw.githubusercontent.com/boostedchaos/offline-emergency-library/main"
KIWIX="https://download.kiwix.org"
UA="Mozilla/5.0"
DEST=""; JOBS=""; MAP_REGIONS=""; WIKI="nopic"; SKIP_MAPS=0; SKIP_MODELS=0; SKIP_AI=0; DRY=0; SKIP_GROUPS=""; CATALOG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--destination) DEST="$2"; shift 2;;
    --wikipedia)      WIKI="$2"; shift 2;;
    --skip-wikipedia) WIKI="none"; shift;;
    --skip-maps)      SKIP_MAPS=1; shift;;
    --map-regions)    MAP_REGIONS="$2"; shift 2;;
    --skip-models)    SKIP_MODELS=1; shift;;
    --skip-ai)        SKIP_AI=1; shift;;
    --skip-groups)    SKIP_GROUPS="$2"; shift 2;;
    --catalog)        CATALOG="$2"; shift 2;;
    --dry-run)        DRY=1; shift;;
    --jobs)           JOBS="$2"; shift 2;;
    *) echo "Unknown option: $1"; exit 2;;
  esac
done
case "$WIKI" in maxi|nopic|mini|none) ;; *) echo "--wikipedia must be maxi, nopic, mini or none"; exit 2;; esac

command -v curl >/dev/null 2>&1 || { echo "ERROR: 'curl' is required."; exit 1; }
HAVE_UNZIP=1; command -v unzip >/dev/null 2>&1 || HAVE_UNZIP=0
HAVE_TAR=1;   command -v tar   >/dev/null 2>&1 || HAVE_TAR=0
if command -v sha256sum >/dev/null 2>&1; then SHA="sha256sum"; else SHA="shasum -a 256"; fi
# --map-regions: OsmAnd spells states with "-" (Us_rhode-island_...), NOMAD with "_" (rhode_island_...)
MR_OSM=""; MR_NOMAD=""
if [ -n "$MAP_REGIONS" ]; then
  mr="$(printf '%s' "$MAP_REGIONS" | tr 'A-Z' 'a-z' | sed -E 's/ *, */,/g; s/^ +| +$//g')"
  MR_OSM="$(printf '%s' "$mr" | tr ' _' '--' | tr ',' '|')"
  MR_NOMAD="$(printf '%s' "$mr" | tr ' -' '__' | tr ',' '|')"
fi
HAVE_ARIA=0; command -v aria2c >/dev/null 2>&1 && HAVE_ARIA=1
[ -z "$JOBS" ] && { JOBS=4; [ "$HAVE_ARIA" = 1 ] && JOBS=2; }   # aria2 opens up to 16 connections per file

if [ -z "$DEST" ] && [ "$DRY" = 0 ]; then
  echo ""
  echo "  Offline Emergency Library installer"
  echo "  -----------------------------------"
  printf "Where would you like to save these files? "
  read -r DEST < /dev/tty      # /dev/tty: works when the script itself arrives on stdin (curl | bash)
  [ -z "$DEST" ] && { echo "No destination given. Exiting."; exit 1; }
fi
ROOT="${DEST:-.}/OfflineLibrary"
if [ "$DRY" = 1 ]; then LOG=/dev/null
else
  mkdir -p "$ROOT" || { echo "Cannot create $ROOT"; exit 1; }
  LOG="$ROOT/_download.log"
  # one run per folder: two runs writing the same file would corrupt it
  if [ -f "$ROOT/_running.pid" ] && kill -0 "$(cat "$ROOT/_running.pid" 2>/dev/null)" 2>/dev/null; then
    echo "Another download is already running into $ROOT (process $(cat "$ROOT/_running.pid")). Wait for it, or close it first."; exit 1
  fi
  echo $$ > "$ROOT/_running.pid"
  trap 'rm -f "$ROOT/_running.pid"' EXIT
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/oel.XXXXXX")"
log(){ printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
SCRIPTDIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

# ---------------------------------------------------------------- download helpers
DRY_BYTES=0; DRY_FILES=0; : > "$WORK/failed.txt"
bad(){ printf '  - %s: %s\n' "$1" "$2" >> "$WORK/failed.txt"; log "  FAILED $1: $2"; }
nfails(){ wc -l < "$WORK/failed.txt" | tr -d ' '; }
fsize(){ wc -c < "$1" | tr -d ' '; }
gb(){ awk -v b="${1:-0}" 'BEGIN{printf "%.2f GB", b/1e9}'; }
real(){ [ "$DRY" = 0 ]; }
skipped(){ case ",$SKIP_GROUPS," in *",$1,"*) return 0;; esac; return 1; }
# head_info URL -> "<final HTTP status> <content-length or empty>" (follows redirects)
head_info(){
  curl -sIL --max-time 60 --retry 3 -A "$UA" "$1" | tr -d '\r' |
    awk '/^HTTP\//{s=$2; n=""} tolower($1)=="content-length:"{n=$2} END{print s, n}'
}
# fetch URL OUT - resumable; fails on HTTP errors; checks size against the server.
fetch(){
  url="$1"; out="$2"; name="$(basename "$out")"
  read -r st want <<EOF
$(head_info "$url")
EOF
  if [ "$st" != 200 ]; then sleep 5; read -r st want <<EOF
$(head_info "$url")
EOF
  fi
  if [ "$DRY" = 1 ]; then
    if [ "$st" = 200 ]; then DRY_BYTES=$((DRY_BYTES + ${want:-0})); DRY_FILES=$((DRY_FILES+1)); log "  ok  $(gb "$want")  $name"
    else bad "$name" "HTTP ${st:-no answer} for $url"; fi
    return 0
  fi
  mkdir -p "$(dirname "$out")"
  if [ -f "$out" ]; then
    if [ -z "$want" ] || [ "$(fsize "$out")" = "$want" ]; then log "  have $name"; return 0; fi
    log "  $name has the wrong size - downloading it again"; rm -f "$out"
  fi
  if [ -f "$out.part" ] && [ -n "$want" ]; then
    ps="$(fsize "$out.part")"
    [ "$ps" -gt "$want" ] && rm -f "$out.part"
    if [ "$ps" = "$want" ]; then mv -f "$out.part" "$out"; log "  done $name"; return 0; fi
  fi
  log "  get  $name $( [ -n "$want" ] && gb "$want")"
  curl -fL -C - --retry 5 --retry-delay 5 --retry-all-errors -s -A "$UA" -o "$out.part" "$url"; rc=$?
  if [ "$rc" != 0 ]; then bad "$name" "download failed (curl exit $rc). Run the script again to resume."; return 1; fi
  got="$(fsize "$out.part")"
  if [ -n "$want" ] && [ "$got" != "$want" ]; then bad "$name" "got $got bytes, server says $want. Run again to resume."; return 1; fi
  mv -f "$out.part" "$out"; log "  done $name"
}
# untar_real ARCHIVE DEST - unpack, turning symlinks into real files. exFAT has no symlinks:
# macOS fakes them with "XSym" files only macOS can read, and Linux cannot make them at all.
# So unpack on the computer's own disk first, then copy with links followed (cp -RL).
untar_real(){
  t="$WORK/untar"; rm -rf "$t"; mkdir -p "$t" "$2"
  tar -xzf "$1" -C "$t" && cp -RL "$t/." "$2/"; rc=$?
  rm -rf "$t"; return $rc
}
# web page / API text (follows redirects)
page(){ curl -fsL --max-time 120 --retry 3 -A "$UA" "$1"; }
gh_asset(){ # repo regex [latest] -> first matching asset url
  u="https://api.github.com/repos/$1/releases?per_page=20"; [ "$3" = latest ] && u="https://api.github.com/repos/$1/releases/latest"
  page "$u" | grep -oE '"browser_download_url"[ ]*:[ ]*"[^"]+"' | sed -E 's/.*"(https[^"]+)"/\1/' | grep -E "$2" | head -n1
}
# newest "<prefix>YYYY-MM.zim" in a Kiwix directory (one listing download per directory)
latest_zim(){ # "dir/prefix"
  d="${1%/*}"; p="${1##*/}"; cache="$WORK/list_$(printf '%s' "$d" | tr '/' '_')"
  [ -s "$cache" ] || page "$KIWIX/zim/$d/" > "$cache"
  re="$(printf '%s' "$p" | sed 's/[.]/\\./g')[0-9]{4}-[0-9]{2}\.zim"
  grep -oE "[\"'>/]$re" "$cache" | cut -c2- | sort -u | tail -n1
}
# ZIMs: add_zim finds the newest file name (one at a time, so listings are read once);
# dl_zim downloads it plus Kiwix's published SHA-256 (checked at the end).
: > "$WORK/zimjobs"
add_zim(){ # "dir/prefix" folder title
  n="$(latest_zim "$1")"
  if [ -z "$n" ]; then bad "$3" "no file matching $1 on $KIWIX"; return; fi
  printf '%s\t%s\t%s\n' "${1%/*}/$n" "$2" "$3" >> "$WORK/zimjobs"
}
dl_zim(){ # "dir/file.zim" folder title
  n="${1##*/}"; log "zim: $3"
  if [ "$DRY" = 0 ] && [ "$HAVE_ARIA" = 1 ]; then aria_get "$KIWIX/zim/$1" "$ROOT/$2/$n" || return
  else fetch "$KIWIX/zim/$1" "$ROOT/$2/$n" || return; fi
  real && { page "$KIWIX/zim/$1.sha256" > "$ROOT/$2/$n.sha256" || rm -f "$ROOT/$2/$n.sha256"; }
}
# aria2: one archive in many pieces from every mirror in Kiwix's .meta4 list.
# aria2 keeps "<file>.aria2" beside an unfinished file; no .aria2 = finished and hash-checked.
aria_get(){ # URL OUT   (URL = $KIWIX/zim/<dir>/<file>)
  url="$1"; out="$2"; name="$(basename "$out")"; d="$(dirname "$out")"; zpath="${url#"$KIWIX"/}"
  if [ -f "$out" ] && [ ! -f "$out.aria2" ]; then
    want="$(head_info "$url" | awk '{print $2}')"
    if [ -z "$want" ] || [ "$(fsize "$out")" = "$want" ]; then log "  have $name"; return 0; fi
    log "  $name has the wrong size - downloading it again"; rm -f "$out"
  fi
  # a curl partial from an older run is a clean start of the file: aria2 continues it
  [ -f "$out.part" ] && [ ! -f "$out" ] && mv -f "$out.part" "$out"
  mkdir -p "$d"; fast_mirrors
  set --; while IFS= read -r b; do set -- "$@" "$b/$zpath"; done < "$WORK/fast_mirrors"
  [ $# -eq 0 ] && set -- "$url"
  sum="$(page "$url.sha256" | awk '{print $1; exit}')"
  ck=""; [ -n "$sum" ] && ck="--checksum=sha-256=$sum"
  log "  get  $name (aria2, $# mirrors)"
  aria2c --dir="$d" --out="$name" --continue=true $ck --piece-length=4M --allow-piece-length-change=true --split=16 --max-connection-per-server=4 \
    --min-split-size=20M --file-allocation=none --max-tries=10 --retry-wait=10 \
    --summary-interval=0 --show-console-readout=false --console-log-level=error --download-result=hide \
    "$@" >> "$WORK/aria2.log" 2>&1; rc=$?
  if [ "$rc" != 0 ] || [ -f "$out.aria2" ] || [ ! -f "$out" ]; then
    bad "$name" "aria2 stopped (exit $rc). Run the script again to resume."; return 1
  fi
  log "  done $name"
}
# Kiwix program files are served by one slow server; its mirrors carry them too.
# Mirror list = the one Kiwix publishes for an archive (.meta4), best first.
kiwix_mirrors(){
  [ -f "$WORK/mirrors" ] && return
  k="$(latest_zim "other/zimgit-knots_en_")"
  page "$KIWIX/zim/other/$k.meta4" 2>/dev/null | grep -oE '<url location="[a-z]+" priority="[0-9]+">[^<]+' |
    sed -E 's/.*">//; s#/zim/other/.*##' > "$WORK/mirrors"
}
# fast_mirrors: once per run, time a 4 MB piece from each mirror; keep the ones >= 1 MB/s.
# (On 2026-11-01 mirror.download.kiwix.org gave 0.07 MB/s and aria2 got stuck on it.)
fast_mirrors(){
  [ -f "$WORK/fast_mirrors" ] && return
  kiwix_mirrors; k="$(latest_zim "other/zimgit-knots_en_")"
  : > "$WORK/fast_mirrors.tmp"
  while IFS= read -r b; do
    sp="$(curl -s -r 0-4194303 -m 10 -o /dev/null -w '%{http_code} %{speed_download}' "$b/zim/other/$k" | awk '$1==206{printf "%d", $2}')"
    if [ "${sp:-0}" -ge 1000000 ]; then echo "$b" >> "$WORK/fast_mirrors.tmp"; log "  mirror ok   $(awk -v s="$sp" 'BEGIN{printf "%.1f", s/1e6}') MB/s  $b"
    else log "  mirror slow $(awk -v s="${sp:-0}" 'BEGIN{printf "%.2f", s/1e6}') MB/s  $b (not used)"; fi
  done < "$WORK/mirrors"
  [ -s "$WORK/fast_mirrors.tmp" ] || cp "$WORK/mirrors" "$WORK/fast_mirrors.tmp"   # none fast: use them all
  mv "$WORK/fast_mirrors.tmp" "$WORK/fast_mirrors"
}
rel_url(){ # path under download.kiwix.org -> first mirror that has it
  kiwix_mirrors
  while IFS= read -r b; do
    [ "$(head_info "$b/$1" | awk '{print $1}')" = 200 ] && { printf '%s/%s' "$b" "$1"; return; }
  done < "$WORK/mirrors"
  printf '%s/%s' "$KIWIX" "$1"
}

# ---------------------------------------------------------------- platform
OSN="$(uname -s)"; ARCHN="$(uname -m)"
case "$ARCHN" in arm64|aarch64) CPU=arm64; JARCH=aarch64;; *) CPU=x64; JARCH=x64;; esac
case "$OSN" in Darwin) PLAT=mac;; *) PLAT=linux;; esac
[ "$DRY" = 1 ] && log "DRY RUN: checking every link and adding up sizes. Nothing is downloaded."
log "Platform: $PLAT/$CPU   Destination: $ROOT   Wikipedia: $WIKI   Skip groups: ${SKIP_GROUPS:-none}"
if [ "$HAVE_ARIA" = 1 ]; then log "aria2 found: archives use many mirrors at once ($JOBS at a time)"
else log "TIP: install aria2 for much faster archive downloads (brew install aria2 / apt install aria2)"; fi
[ "$HAVE_UNZIP" = 0 ] && log "NOTE: 'unzip' not found - the desktop map viewer and Windows reader need it."

# ================================================================ 1-2. Offline AI (every platform)
# llama.cpp builds for Windows, macOS and Linux, all from ONE build so they match.
# Its llama-server includes a chat web page that also reads PDFs (replaces GPT4All,
# whose last release was 2025-02 and cannot load current models).
LLAMA_ASSETS="win-cpu-x64.zip win-cpu-arm64.zip win-vulkan-x64.zip macos-arm64.tar.gz macos-x64.tar.gz ubuntu-x64.tar.gz ubuntu-arm64.tar.gz ubuntu-vulkan-x64.tar.gz"
# Models: small + medium, both Apache-2.0. File names are also used by AI-CHAT launchers.
SMALL_REPO="unsloth/Qwen3.5-4B-GGUF";           SMALL_FILE="Qwen3.5-4B-Q4_K_M.gguf"
MEDIUM_REPO="google/gemma-4-12B-it-qat-q4_0-gguf"; MEDIUM_FILE="gemma-4-12b-it-qat-q4_0.gguf"
if [ "$SKIP_AI" = 0 ]; then
log "=== [1/9] Offline AI engine (llama.cpp) for Windows, macOS and Linux ==="
E="$ROOT/AI-Offline/engine"
page "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=20" > "$WORK/llama.json"
grep -oE '"browser_download_url"[ ]*:[ ]*"[^"]+"' "$WORK/llama.json" | sed -E 's/.*"(https[^"]+)"/\1/' > "$WORK/llama.urls"
LT=""
for t in $(grep -oE '"tag_name"[ ]*:[ ]*"[^"]+"' "$WORK/llama.json" | sed -E 's/.*"([^"]+)"$/\1/'); do
  ok=1; for a in $LLAMA_ASSETS; do grep -q "/download/$t/llama-$t-bin-$a\$" "$WORK/llama.urls" || { ok=0; break; }; done
  [ "$ok" = 1 ] && { LT="$t"; break; }
done
if [ -z "$LT" ]; then bad "llama.cpp" "no recent build has all 8 platform files"
else
  log "llama.cpp build: $LT"
  for a in $LLAMA_ASSETS; do
    d="${a%.zip}"; d="${d%.tar.gz}"
    if fetch "https://github.com/ggml-org/llama.cpp/releases/download/$LT/llama-$LT-bin-$a" "$E/$a" && real; then
      [ -n "$d" ] && rm -rf "${E:?}/$d"; mkdir -p "$E/$d"     # fresh unpack: no stale files from an older build
      case "$a" in
        *.zip)    if [ "$HAVE_UNZIP" = 1 ]; then unzip -o -q "$E/$a" -d "$E/$d"; else log "  $a: install unzip to unpack it"; fi ;;
        *.tar.gz) untar_real "$E/$a" "$E/$d" || bad "$a" "could not unpack it" ;;
      esac
    fi
  done
  real && echo "$LT" > "$E/BUILD.txt"
fi

log "=== [2/9] AI chat models (GGUF) ==="
M="$ROOT/AI-Offline/models"
# get_model REPO FILE - download, then save Hugging Face's published SHA-256 (checked at the end)
get_model(){
  u="https://huggingface.co/$1/resolve/main/$2"
  fetch "$u" "$M/$2" || return
  real || return
  h="$(curl -sI --max-time 60 -A "$UA" "$u" | tr -d '\r' | awk 'tolower($1)=="x-linked-etag:"{gsub(/"/,"",$2); print $2}')"
  case "$h" in [0-9a-f][0-9a-f]*) [ ${#h} = 64 ] && printf '%s  %s\n' "$h" "$2" > "$M/$2.sha256";; esac
}
get_model "$SMALL_REPO" "$SMALL_FILE"
if [ "$SKIP_MODELS" = 0 ]; then get_model "$MEDIUM_REPO" "$MEDIUM_FILE"; else log "models: medium model skipped"; fi
else log "=== [1-2/9] Offline AI SKIPPED ==="; fi

# ================================================================ 4. Library readers (every platform)
log "=== [4/9] Library readers for Windows, macOS and Linux (Kiwix) ==="
KT="$ROOT/Kiwix-Reader/tools"
page "$KIWIX/release/kiwix-tools/" > "$WORK/kiwix-tools.html"
for p in win-x86_64 macos-arm64 macos-x86_64 linux-x86_64 linux-aarch64; do
  f="$(grep -oE "kiwix-tools_${p}-[0-9][0-9.]*[0-9]\.(tar\.gz|zip)" "$WORK/kiwix-tools.html" | sort -u -V | tail -n1)"
  if [ -z "$f" ]; then bad "kiwix-tools $p" "not found"; continue; fi
  fetch "$(rel_url "release/kiwix-tools/$f")" "$KT/$f" || continue
  real || continue
  mkdir -p "$KT/$p"
  case "$f" in
    *.zip)    [ "$HAVE_UNZIP" = 1 ] && unzip -o -q "$KT/$f" -d "$KT/$p" ;;
    *.tar.gz) untar_real "$KT/$f" "$KT/$p" || bad "$f" "could not unpack it" ;;
  esac
done
page "$KIWIX/release/kiwix-desktop/" > "$WORK/kiwix-desktop.html"
ai="$(grep -oE 'kiwix-desktop_x86_64_[0-9][0-9.]*[0-9]\.appimage' "$WORK/kiwix-desktop.html" | sort -u -V | tail -n1)"
[ -n "$ai" ] && fetch "$(rel_url "release/kiwix-desktop/$ai")" "$ROOT/Kiwix-Reader/$ai" && chmod +x "$ROOT/Kiwix-Reader/$ai" 2>/dev/null
wz="$(grep -oE 'kiwix-desktop_windows_x64_[0-9][0-9.]*[0-9]\.zip' "$WORK/kiwix-desktop.html" | sort -u -V | tail -n1)"
if [ -n "$wz" ] && fetch "$(rel_url "release/kiwix-desktop/$wz")" "$ROOT/Kiwix-Reader/$wz" && real && [ "$HAVE_UNZIP" = 1 ]; then
  unzip -o -q "$ROOT/Kiwix-Reader/$wz" -d "$ROOT/Kiwix-Reader/app"
fi

# ================================================================ 5. Wikipedia
if [ "$WIKI" != none ]; then
  log "=== [5/9] Wikipedia ($WIKI) ==="
  add_zim "wikipedia/wikipedia_en_all_${WIKI}_" "Wikipedia" "Wikipedia ($WIKI)"
else log "=== [5/9] Wikipedia SKIPPED ==="; fi

# ================================================================ 6. ZIM archives from the catalog
log "=== [6/9] Offline archives (Kiwix ZIM) ==="
if [ -n "$CATALOG" ]; then cp "$CATALOG" "$WORK/zims.tsv"
elif [ -f "$SCRIPTDIR/catalog/zims.tsv" ]; then cp "$SCRIPTDIR/catalog/zims.tsv" "$WORK/zims.tsv"
else page "$REPO_RAW/catalog/zims.tsv" > "$WORK/zims.tsv"; fi
[ -s "$WORK/zims.tsv" ] || bad "catalog" "could not read catalog/zims.tsv"
while IFS="$(printf '\t')" read -r grp folder zpath note title; do
  case "$grp" in ''|'#'*) continue;; esac
  skipped "$grp" && continue
  if [ "$note" = dupwiki ] && { [ "$WIKI" = maxi ] || [ "$WIKI" = nopic ]; }; then continue; fi
  add_zim "$zpath" "$folder" "$title"
done < "$WORK/zims.tsv"
log "archives to get: $(wc -l < "$WORK/zimjobs" | tr -d ' ')   (up to $JOBS at a time)"
[ "$DRY" = 0 ] && [ "$HAVE_ARIA" = 1 ] && { log "Testing Kiwix mirrors:"; fast_mirrors; }
while IFS="$(printf '\t')" read -r zp folder title; do
  if [ "$DRY" = 1 ]; then dl_zim "$zp" "$folder" "$title"; continue; fi
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 2; done
  dl_zim "$zp" "$folder" "$title" &
done < "$WORK/zimjobs"
wait

# ================================================================ 7. PDFs
if ! skipped pdfs; then
log "=== [7/9] Books (PDF) ==="
AFM="$ROOT/Manuals/ArmyFieldManuals"; MPDF="$ROOT/Medical/Manuals-PDF"
get_ia(){ # archive.org id, local name, folder
  f="$(page "https://archive.org/metadata/$1" | grep -oE '"name":"[^"]+\.pdf"' | sed -E 's/"name":"([^"]+)"/\1/' | grep -vE '_text\.pdf$' | head -n1)"
  if [ -z "$f" ]; then bad "$2" "no PDF in archive.org item $1"; return; fi
  fetch "https://archive.org/download/$1/$(printf '%s' "$f" | sed 's/ /%20/g')" "$3/$2"
}
get_ia "fm-21-76-us-army-survival-manual"                    "FM 21-76 Army Survival Manual.pdf" "$AFM"
get_ia "fm-3-05.70-survival-2002"                            "FM 3-05.70 Survival (2002).pdf" "$AFM"
get_ia "105-page-survival-field-manual"                      "105-Page Survival Field Manual.pdf" "$AFM"
get_ia "UsArmyFirstAidManualFm4-25.11"                       "FM 4-25.11 First Aid.pdf" "$AFM"
get_ia "Survival-FirstAidForSoldiers-AFieldManual"           "Survival and First Aid for Soldiers.pdf" "$AFM"
get_ia "use-and-care-of-hand-tools-and-measuring-tools-1983" "TM 9-243 Use and Care of Hand Tools.pdf" "$AFM"
get_ia "fm-5-426-carpentry-1995"                             "FM 5-426 Carpentry.pdf" "$AFM"
get_ia "tm-9-8000-principles-of-automotive-vehicles-1985"    "TM 9-8000 Principles of Automotive Vehicles.pdf" "$AFM"
get_ia "u-s-army-guide-to-rigging"                           "FM 5-125 Army Guide to Rigging.pdf" "$AFM"
get_ia "fm-90-3-desert-operations-1993"                      "FM 90-3 Desert Operations.pdf" "$AFM"
get_ia "tm-10-412-armed-forces-recipe-service-2003"          "TM 10-412 Armed Forces Recipe Service.pdf" "$AFM"
# Hesperian health books: downloaded from Hesperian's own page at run time (they ask
# people to use that page, because their PDF file names change). One PDF per chapter.
HESP="https://languages.hesperian.org/pages/en/pdf.html"
page "$HESP" > "$WORK/hesperian.html" || bad "Hesperian" "could not read $HESP"
get_hesperian(){ # book code, folder name
  dir="$(grep -oE "uploads/pdf/en_$1_[0-9]{4}/" "$WORK/hesperian.html" | sort -u | tail -n1)"
  if [ -z "$dir" ]; then bad "$2" "not listed on $HESP"; return; fi
  log "pdf: $2 ($dir)"; i=0
  for u in $(grep -oE "https://hesperian\.org/wp-content/$dir[^\"]+\.pdf" "$WORK/hesperian.html" | awk '!s[$0]++'); do
    i=$((i+1)); fetch "$u" "$MPDF/$2/$(printf '%02d' "$i")-$(basename "$u")"
  done
}
get_hesperian wtnd "Where There Is No Doctor (Hesperian)"
get_hesperian dent "Where There Is No Dentist (Hesperian)"
else log "=== [7/9] PDFs SKIPPED ==="; fi

# ================================================================ 8. Maps
if [ "$SKIP_MAPS" = 0 ]; then
  log "=== [8/9] Offline US maps (OsmAnd) ==="
  page "https://download.osmand.net/get_indexes" > "$WORK/osmand.xml"
  grep 'type="map"' "$WORK/osmand.xml" | grep -oE 'name="[Uu][Ss]_[^"]+\.obf\.zip"' | sed -E 's/name="([^"]+)"/\1/' | sort -u > "$WORK/osmand.txt"
  if [ -n "$MR_OSM" ]; then grep -E "^Us_($MR_OSM)_" "$WORK/osmand.txt" > "$WORK/osmand.f"; mv "$WORK/osmand.f" "$WORK/osmand.txt"; fi
  log "osmand: $(wc -l < "$WORK/osmand.txt" | tr -d ' ') US map files${MAP_REGIONS:+ (regions: $MAP_REGIONS)}"
  [ -s "$WORK/osmand.txt" ] || bad "OsmAnd maps" "no US maps found in the OsmAnd index"
  while IFS= read -r fn; do fetch "https://download.osmand.net/download.php?standard=yes&file=$fn" "$ROOT/OsmAnd/$fn"; done < "$WORK/osmand.txt"

  log "=== [8b] Desktop map viewer (OsmAndMapCreator + portable Java) ==="
  MVD="$ROOT/OsmAnd/MapViewer-Desktop"
  if [ "$HAVE_UNZIP" = 1 ]; then
    fetch "https://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip" "$MVD/OsmAndMapCreator.zip" &&
      real && unzip -o -q "$MVD/OsmAndMapCreator.zip" -d "$MVD/app"
    jos="$PLAT"; [ "$PLAT" = linux ] || jos=mac
    if fetch "https://api.adoptium.net/v3/binary/latest/21/ga/${jos}/${JARCH}/jre/hotspot/normal/eclipse" "$MVD/jre.tar.gz" && real; then
      mkdir -p "$MVD/_jre"; untar_real "$MVD/jre.tar.gz" "$MVD/_jre"
      rm -rf "$MVD/jre"; mv "$MVD/_jre"/*/ "$MVD/jre" 2>/dev/null; rm -rf "$MVD/_jre"
    fi
    if real; then
      cat > "$MVD/VIEW-MAPS-ON-PC.sh" <<'EOS'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
JAVA="$(find "$DIR/jre" -name java -type f 2>/dev/null | head -n1)"
[ -n "$JAVA" ] && export PATH="$(dirname "$JAVA"):$PATH"
MAPS="$(cd "$DIR/.." && pwd)"; OBF="$MAPS/obf"; mkdir -p "$OBF"
echo "Preparing maps for desktop viewing (first run can take several minutes)..."
for z in "$MAPS"/*.obf.zip; do
  [ -e "$z" ] || continue
  base="$(basename "$z" .zip)"
  [ -e "$OBF/$base" ] || unzip -o -q "$z" -d "$OBF"
done
echo "Maps ready in: $OBF"
bash "$DIR/app/OsmAndMapCreator.sh"
EOS
      chmod +x "$MVD/VIEW-MAPS-ON-PC.sh" 2>/dev/null
      find "$MVD/app" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
      find "$MVD/jre" -name java -exec chmod +x {} \; 2>/dev/null
    fi
  else log "desktop map viewer: skipped (install 'unzip' then re-run)"; fi

  # ---- browser maps: Protomaps state extracts made by Project NOMAD (MIT; map data
  # (c) OpenStreetMap contributors, ODbL), NOMAD's style/fonts/symbols, MapLibre viewer,
  # and Caddy (Apache-2.0) to serve them - OPEN-MAPS opens them in any web browser.
  log "=== [8c] Browser maps (Project NOMAD / Protomaps) + viewer ==="
  MB="$ROOT/Maps-Browser"
  NM="https://github.com/Crosstalk-Solutions/project-nomad-maps/raw/refs/heads/master"
  page "https://api.github.com/repos/Crosstalk-Solutions/project-nomad-maps/contents/pmtiles" |
    grep -oE '"name"[ ]*:[ ]*"[a-z_-]+_[0-9]{4}-[0-9]{2}\.pmtiles"' | sed -E 's/.*"([^"]+)"$/\1/' | LC_ALL=C sort > "$WORK/nomad-maps.txt"
  if [ -n "$MR_NOMAD" ]; then grep -E "^(global[a-z-]*|$MR_NOMAD)_[0-9]{4}-[0-9]{2}\.pmtiles$" "$WORK/nomad-maps.txt" > "$WORK/nm.f"; mv "$WORK/nm.f" "$WORK/nomad-maps.txt"; fi
  # newest file per region (names end _YYYY-MM.pmtiles); world map first so states draw over it
  sed -E 's/_[0-9]{4}-[0-9]{2}\.pmtiles$//' "$WORK/nomad-maps.txt" | sort -u | while IFS= read -r r; do
    grep -E "^${r}_[0-9]{4}-[0-9]{2}\.pmtiles$" "$WORK/nomad-maps.txt" | tail -n1
  done | awk '/^global/{print; next} {rest=rest $0 "\n"} END{printf "%s", rest}' > "$WORK/nomad-latest.txt"
  log "browser maps: $(wc -l < "$WORK/nomad-latest.txt" | tr -d ' ') map files"
  [ -s "$WORK/nomad-latest.txt" ] || bad "browser maps" "no map list from the project-nomad-maps repo"
  : > "$WORK/regions.txt"
  while IFS= read -r fn; do
    fetch "$NM/pmtiles/$fn" "$MB/pmtiles/$fn" || continue
    real || continue
    # no published fingerprints: check the PMTiles header (the file starts with "PMTiles")
    if [ "$(head -c 7 "$MB/pmtiles/$fn")" = "PMTiles" ]; then echo "$fn" >> "$WORK/regions.txt"
    else bad "$fn" "not a PMTiles file - deleted it, run again"; rm -f "$MB/pmtiles/$fn"; fi
  done < "$WORK/nomad-latest.txt"
  if real && [ -s "$WORK/regions.txt" ]; then
    { printf '['; sed 's/.*/"&"/' "$WORK/regions.txt" | paste -sd, -; printf ']\n'; } > "$MB/regions.json"
  fi
  if fetch "$NM/base-assets.tar.gz" "$MB/base-assets.tar.gz" && real; then
    rm -rf "$MB/assets-new"
    if untar_real "$MB/base-assets.tar.gz" "$MB/assets-new" && [ -f "$MB/assets-new/tozip/nomad-base-styles.json" ]; then
      rm -rf "$MB/assets"; mv "$MB/assets-new/tozip" "$MB/assets"; rm -rf "$MB/assets-new"
    else bad "base-assets.tar.gz" "could not unpack the map style and fonts"; fi
  fi
  for u in maplibre-gl@4.7.1/dist/maplibre-gl.js maplibre-gl@4.7.1/dist/maplibre-gl.css pmtiles@4.4.0/dist/pmtiles.js; do
    fetch "https://unpkg.com/$u" "$MB/viewer/lib/$(basename "$u")"
  done
  # Caddy web server for every platform (one release)
  page "https://api.github.com/repos/caddyserver/caddy/releases/latest" > "$WORK/caddy.json"
  for ck in windows_amd64.zip windows_arm64.zip mac_arm64.tar.gz mac_amd64.tar.gz linux_amd64.tar.gz linux_arm64.tar.gz; do
    cu="$(grep -oE '"browser_download_url"[ ]*:[ ]*"[^"]+_'"$ck"'"' "$WORK/caddy.json" | sed -E 's/.*"(https[^"]+)"$/\1/' | head -n1)"
    if [ -z "$cu" ]; then bad "caddy $ck" "not in the latest Caddy release"; continue; fi
    cd_="${ck%.zip}"; cd_="${cd_%.tar.gz}"; cd_="$(printf '%s' "$cd_" | tr '_' '-')"
    if fetch "$cu" "$MB/server/$(basename "$cu")" && real; then
      case "$ck" in
        *.zip)    [ "$HAVE_UNZIP" = 1 ] && unzip -o -q "$MB/server/$(basename "$cu")" -d "$MB/server/$cd_" ;;   # keep LICENSE (Apache-2.0)
        *.tar.gz) untar_real "$MB/server/$(basename "$cu")" "$MB/server/$cd_" ;;
      esac
    fi
  done
else log "=== [8/9] Maps SKIPPED ==="; fi

# ================================================================ phone apps
log "=== Phone apps (Android) ==="
PA="$ROOT/Phone-Apps"
ku="$(gh_asset kiwix/kiwix-android 'universal-standalone\.apk$' latest)"
[ -z "$ku" ] && ku="$(gh_asset kiwix/kiwix-android '\.apk$' latest)"
if [ -n "$ku" ]; then fetch "$ku" "$PA/$(basename "$ku")"; else bad "Kiwix Android app" "no release asset found"; fi
if [ "$SKIP_MAPS" = 0 ]; then
  vc="$(page https://f-droid.org/api/v1/packages/net.osmand.plus | grep -oE '"suggestedVersionCode":[0-9]+' | grep -oE '[0-9]+' | head -n1)"
  if [ -n "$vc" ]; then fetch "https://f-droid.org/repo/net.osmand.plus_$vc.apk" "$PA/OsmAnd-$vc.apk"; else bad "OsmAnd Android app" "F-Droid did not answer"; fi
fi

if [ "$DRY" = 1 ]; then
  log "=== DRY RUN RESULT ==="
  log "Files: $DRY_FILES   Total download: $(gb "$DRY_BYTES")"
  if [ -n "$DEST" ] && [ -d "$DEST" ]; then
    free=$(( $(df -Pk "$DEST" | awk 'NR==2{print $4}') * 1024 )); log "Free space at $DEST: $(gb "$free")"
  fi
  if [ "$(nfails)" -gt 0 ]; then log "$(nfails) link(s) did not work:"; cat "$WORK/failed.txt" | tee -a "$LOG"; rm -rf "$WORK"; exit 1; fi
  log "All links work."; rm -rf "$WORK"; exit 0
fi

# ================================================================ documentation + drive tools
log "=== Documentation and drive tools ==="
place(){ # repo-path dest-path
  mkdir -p "$(dirname "$2")"
  if [ -f "$SCRIPTDIR/$1" ]; then cp "$SCRIPTDIR/$1" "$2"
  else page "$REPO_RAW/$1" > "$2" || { rm -f "$2"; bad "$(basename "$1")" "could not get it from $REPO_RAW"; return; }; fi
  # Windows .bat/.ps1 files need CRLF line ends (GitHub serves them with LF)
  case "$2" in *.bat|*.ps1) awk '{sub(/\r$/,""); printf "%s\r\n", $0}' "$2" > "$2.tmp" && mv -f "$2.tmp" "$2";; esac
}
place_doc(){ place "docs/$1.md" "$2.md"; place "docs/$1.html" "$2.html"; }
place_doc "START-HERE"            "$ROOT/START-HERE"
place_doc "HOW-TO-RUN-OFFLINE-AI" "$ROOT/AI-Offline/HOW-TO-RUN-OFFLINE-AI"
place_doc "HOW-TO-ASK-YOUR-DOCS"  "$ROOT/AI-Offline/HOW-TO-ASK-YOUR-DOCS"
place_doc "HOW-TO-USE-KIWIX"      "$ROOT/Kiwix-Reader/HOW-TO-USE-KIWIX"
place_doc "Manuals-READ-ME-FIRST" "$ROOT/Manuals/READ-ME-FIRST"
place_doc "Medical-READ-ME-FIRST" "$ROOT/Medical/READ-ME-FIRST"
place_doc "RADIO-GUIDE"           "$ROOT/Manuals/Radio-Communications/RADIO-GUIDE"
place_doc "HOW-TO-VIEW-MAPS"      "$ROOT/OsmAnd/HOW-TO-VIEW-MAPS"
place_doc "USE-ON-PHONE"          "$ROOT/Phone-Apps/USE-ON-PHONE"
for f in OPEN-LIBRARY.command OPEN-LIBRARY.sh OPEN-LIBRARY.bat CHECK-DRIVE.command CHECK-DRIVE.sh CHECK-DRIVE.bat check-drive.ps1; do
  place "drive/$f" "$ROOT/$f"
done
if [ "$SKIP_AI" = 0 ]; then for f in AI-CHAT.command AI-CHAT.sh AI-CHAT.bat; do place "drive/$f" "$ROOT/$f"; done; fi
if [ "$SKIP_MAPS" = 0 ]; then
  for f in OPEN-MAPS.command OPEN-MAPS.sh OPEN-MAPS.bat; do place "drive/$f" "$ROOT/$f"; done
  place "drive/maps/index.html" "$ROOT/Maps-Browser/viewer/index.html"
fi
chmod +x "$ROOT"/*.command "$ROOT"/*.sh 2>/dev/null

# ================================================================ README index
log "=== Building README.html (full index of everything) ==="
IDX="$ROOT/README.html"
IDXCSS='<style>:root{--bg:#0f1420;--card:#171f2e;--ink:#e7ecf3;--muted:#9fb0c3;--accent:#4fd1c5;--accent2:#f6ad55;--line:#273246;--code:#0b0f17}@media(prefers-color-scheme:light){:root{--bg:#f4f6fb;--card:#fff;--ink:#15202b;--muted:#56657a;--accent:#0d9488;--accent2:#b45309;--line:#e2e8f0;--code:#f1f5f9}}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.65 -apple-system,Segoe UI,Roboto,Arial,sans-serif}.wrap{max-width:1000px;margin:0 auto;padding:28px 20px 80px}h1{font-size:30px;background:linear-gradient(135deg,var(--accent),var(--accent2));-webkit-background-clip:text;background-clip:text;color:transparent}h2{font-size:21px;border-bottom:2px solid var(--line);padding-bottom:6px;margin-top:32px}a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}code{background:var(--code);padding:2px 6px;border-radius:6px;font-family:Consolas,monospace;font-size:13px}table{border-collapse:collapse;width:100%;margin:10px 0;font-size:14.5px}th,td{border:1px solid var(--line);padding:8px 11px;text-align:left;vertical-align:top}th{background:rgba(127,127,127,.12)}.muted{color:var(--muted);font-size:13px}.hero{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 20px;margin:14px 0}</style>'
relp(){ printf '%s' "${1#"$ROOT"/}"; }
nicen(){ b="$(basename "$1")"; b="${b%.*}"; printf '%s' "$b" | tr '_-' '  '; }
hsz(){ du -h "$1" 2>/dev/null | cut -f1; }
{
  printf '%s' "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Offline Emergency Library - Full Index</title>$IDXCSS</head><body><div class=\"wrap\">"
  printf '%s' "<h1>&#128703; Offline Emergency Library &mdash; Full Index</h1>"
  printf '%s' "<div class='hero'>Every guide, document, manual, archive, app and data file on this drive, with links.<br>To read the archives, run <b>OPEN-LIBRARY</b> (.command on Mac, .bat on Windows, .sh on Linux).<br><span class='muted'>Generated $(date '+%Y-%m-%d %H:%M')</span></div>"
  [ -f "$ROOT/START-HERE.html" ] && printf '%s' "<p>&#128073; New here? Start with <a href='START-HERE.html'><b>START-HERE.html</b></a>.</p>"
  printf '%s' "<h2>&#128214; Guides &amp; Documentation</h2><table><tr><th>Guide</th><th>Folder</th><th>Open</th></tr>"
  find "$ROOT" -type f -name '*.html' ! -name 'README.html' ! -name '._*' ! -path '*/Kiwix-Reader/app/*' ! -path '*/MapViewer-Desktop/*' | sort | while read -r f; do
    rel="$(relp "$f")"; dir="$(dirname "$rel")"; [ "$dir" = "." ] && dir='(root)'
    mdrel="${rel%.html}.md"; ml=""; [ -f "$ROOT/$mdrel" ] && ml=" &middot; <a href='$mdrel'>md</a>"
    printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$dir</td><td><a href='$rel'>HTML</a>$ml</td></tr>"
  done
  printf '%s' "</table>"
  if find "$ROOT" -type f -name '*.pdf' | grep -q .; then
    printf '%s' "<h2>&#128218; Manuals &amp; Books (PDF)</h2><table><tr><th>Document</th><th>Folder</th><th>Size</th><th>Open</th></tr>"
    find "$ROOT" -type f -name '*.pdf' ! -name '._*' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td><td><a href='$rel'>PDF</a></td></tr>"; done
    printf '%s' "</table>"
  fi
  if find "$ROOT" -type f -name '*.zim' | grep -q .; then
    printf '%s' "<h2>&#127760; Offline Archives (ZIM &mdash; open with OPEN-LIBRARY or Kiwix)</h2><table><tr><th>Archive</th><th>Folder</th><th>Size</th></tr>"
    find "$ROOT" -type f -name '*.zim' ! -name '._*' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td></tr>"; done
    printf '%s' "</table>"
  fi
  printf '%s' "<h2>&#9881; Programs &amp; Launchers</h2><table><tr><th>Item</th><th>Folder</th></tr>"
  find "$ROOT" -maxdepth 3 -type f \( -name '*.bat' -o -name '*.sh' -o -name '*.command' -o -name '*.appimage' -o -name '*.run' -o -name '*.dmg' \) ! -name '._*' ! -path '*/app/*' | sort -u | while read -r f; do rel="$(relp "$f")"; dir="$(dirname "$rel")"; [ "$dir" = "." ] && dir='(root)'; printf '%s' "<tr><td><a href='$rel'>$(basename "$f")</a></td><td class='muted'>$dir</td></tr>"; done
  printf '%s' "</table>"
  if find "$ROOT" -type f -name '*.apk' | grep -q .; then
    printf '%s' "<h2>&#128241; Phone Apps (Android APK)</h2><table><tr><th>App</th><th>Folder</th><th>Size</th></tr>"
    find "$ROOT" -type f -name '*.apk' ! -name '._*' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td><a href='$rel'>$(basename "$f")</a></td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td></tr>"; done
    printf '%s' "</table>"
  fi
  mc=$(find "$ROOT/OsmAnd" -maxdepth 1 -type f -name '*.obf.zip' ! -name '._*' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$mc" -gt 0 ]; then
    printf '%s' "<h2>&#128451; Maps</h2><table><tr><th>Item</th><th>Folder</th><th>Size</th></tr>"
    printf '%s' "<tr><td>Offline US maps - $mc files</td><td class='muted'>OsmAnd</td><td>$(find "$ROOT/OsmAnd" -maxdepth 1 -type f -name '*.obf.zip' ! -name '._*' -print0 | xargs -0 du -ch 2>/dev/null | tail -1 | cut -f1)</td></tr></table>"
  fi
  printf '%s' "</div></body></html>"
} > "$IDX"

# ================================================================ library list for OPEN-LIBRARY
# One kiwix-manage call writes library.xml with paths relative to it, so OPEN-LIBRARY can
# serve every archive at once on any computer (no per-start scan of 60+ big files).
log "=== Library list for OPEN-LIBRARY (library.xml) ==="
case "$PLAT-$CPU" in mac-arm64) kp=macos-arm64;; mac-*) kp=macos-x86_64;; linux-arm64) kp=linux-aarch64;; *) kp=linux-x86_64;; esac
KM="$(find "$ROOT/Kiwix-Reader/tools/$kp" -name kiwix-manage -type f 2>/dev/null | head -n1)"
if [ -n "$KM" ]; then
  KM="$(cd "$(dirname "$KM")" && pwd)/kiwix-manage"; chmod +x "$KM" 2>/dev/null
  ( cd "$ROOT" && find . -type f -name '*.zim' ! -name '._*' | sed 's#^\./##' | LC_ALL=C sort |
      while IFS= read -r z; do [ -f "$z.aria2" ] || printf '%s\0' "$z"; done > "$WORK/zimlist0"
    rm -f library.xml.new
    if [ ! -s "$WORK/zimlist0" ]; then rm -f library.xml; exit 0; fi     # no archives: nothing to list
    if xargs -0 "$KM" library.xml.new add < "$WORK/zimlist0" >/dev/null 2>&1; then
      mv -f library.xml.new library.xml
    else rm -f library.xml.new; exit 1; fi ) || bad "library.xml" "kiwix-manage could not build it (OPEN-LIBRARY will scan the drive instead)"
  [ -f "$ROOT/library.xml" ] && log "library.xml: $(grep -c '<book ' "$ROOT/library.xml") archives"
else log "library.xml: skipped (no kiwix-manage for $kp)"; fi

# ================================================================ checksums
# One fingerprint per file, so CHECK-DRIVE can prove nothing has rotted.
# Same format on every OS: "<lowercase sha256>  ./path/with/forward/slashes".
log "=== Fingerprinting every file (SHA256SUMS.txt) - this takes a while ==="
( cd "$ROOT" && find . -type f \
    ! -name 'SHA256SUMS.txt*' ! -name '._*' ! -name '.DS_Store' ! -name '*.part' ! -name '*.aria2' ! -name '*.sha256' ! -name '_*' \
    ! -path './.Spotlight-V100/*' ! -path './.fseventsd/*' ! -path './.Trashes/*' ! -path './System Volume Information/*' |
  LC_ALL=C sort | while IFS= read -r f; do $SHA "$f" || echo "HASHFAIL $f" >&2; done ) > "$ROOT/SHA256SUMS.txt.new" 2> "$WORK/hashfail.txt"
if [ -s "$WORK/hashfail.txt" ]; then bad "checksums" "could not read: $(tr '\n' ' ' < "$WORK/hashfail.txt")"; fi
mv -f "$ROOT/SHA256SUMS.txt.new" "$ROOT/SHA256SUMS.txt"
log "SHA256SUMS.txt: $(wc -l < "$ROOT/SHA256SUMS.txt" | tr -d ' ') files"

# Compare each ZIM with the SHA-256 that Kiwix publishes for it.
log "=== Checking files against their publishers' fingerprints (Kiwix, Hugging Face) ==="
zok=0; znone=0
while IFS= read -r s; do
  z="${s%.sha256}"; rel="./${z#"$ROOT"/}"
  [ -f "$z.aria2" ] && continue      # unfinished aria2 download: already listed as a problem
  want="$(awk '{print $1; exit}' "$s" | tr 'A-F' 'a-f')"
  got="$(awk -v p="$rel" 'substr($0, 67) == p {print $1; exit}' "$ROOT/SHA256SUMS.txt")"
  if [ -n "$want" ] && [ "$want" = "$got" ]; then zok=$((zok+1))
  elif [ -n "$want" ] && [ -f "$z" ]; then bad "$(basename "$z")" "does not match its publisher's fingerprint (damaged download). Deleted it - run the script again."; rm -f "$z"
  fi
done < <(find "$ROOT" -type f \( -name '*.zim.sha256' -o -name '*.gguf.sha256' \) ! -name '._*')
while IFS= read -r z; do [ -f "$z.sha256" ] || [ -f "$z.aria2" ] || znone=$((znone+1)); done < <(find "$ROOT" -type f -name '*.zim' ! -name '._*')
log "files matching their publisher's fingerprint: $zok   (archives with no published fingerprint: $znone)"

echo ""
if [ "$(nfails)" -gt 0 ]; then
  log "=== FINISHED WITH $(nfails) PROBLEM(S) ==="; cat "$WORK/failed.txt" | tee -a "$LOG"
  log "Run the same command again. It keeps what worked and retries the rest."
  rm -rf "$WORK"; exit 1
fi
rm -rf "$WORK"
log "=== DONE. Everything downloaded and checked. ==="
echo "  Your offline library is in: $ROOT"
echo "  Open README.html for a full index. Run OPEN-LIBRARY to read the archives."
echo "  Run CHECK-DRIVE once a year to prove nothing has rotted."

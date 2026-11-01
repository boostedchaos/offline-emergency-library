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
#   --skip-wikipedia  --skip-maps  --skip-models  --skip-ai
#   --catalog FILE                     use another ZIM list (default: catalog/zims.tsv)
#   --jobs N                           archives downloaded at the same time (default 4)

REPO_RAW="https://raw.githubusercontent.com/boostedchaos/offline-emergency-library/main"
KIWIX="https://download.kiwix.org"
UA="Mozilla/5.0"
DEST=""; JOBS=4; WIKI="nopic"; SKIP_MAPS=0; SKIP_MODELS=0; SKIP_AI=0; DRY=0; SKIP_GROUPS=""; CATALOG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--destination) DEST="$2"; shift 2;;
    --wikipedia)      WIKI="$2"; shift 2;;
    --skip-wikipedia) WIKI="none"; shift;;
    --skip-maps)      SKIP_MAPS=1; shift;;
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
  fetch "$KIWIX/zim/$1" "$ROOT/$2/$n" || return
  real && { page "$KIWIX/zim/$1.sha256" > "$ROOT/$2/$n.sha256" || rm -f "$ROOT/$2/$n.sha256"; }
}
# Kiwix program files are served by one slow server; its mirrors carry them too.
# Mirror list = the one Kiwix publishes for an archive (.meta4), best first.
kiwix_mirrors(){
  [ -f "$WORK/mirrors" ] && return
  k="$(latest_zim "other/zimgit-knots_en_")"
  page "$KIWIX/zim/other/$k.meta4" 2>/dev/null | grep -oE '<url location="[a-z]+" priority="[0-9]+">[^<]+' |
    sed -E 's/.*">//; s#/zim/other/.*##' > "$WORK/mirrors"
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
[ "$HAVE_UNZIP" = 0 ] && log "NOTE: 'unzip' not found - the desktop map viewer and Windows reader need it."

# ================================================================ 1. AI engine
if [ "$SKIP_AI" = 0 ]; then
log "=== [1/9] Offline AI engine (llama.cpp) ==="
E="$ROOT/AI-Offline/engine"
if [ "$PLAT" = mac ]; then set -- "metal:bin-macos-${CPU}\\.tar\\.gz$"
else set -- "cpu:bin-ubuntu-${CPU}\\.tar\\.gz$" "gpu:bin-ubuntu-vulkan-${CPU}\\.tar\\.gz$"; fi
for spec in "$@"; do
  sub="${spec%%:*}"; u="$(gh_asset ggml-org/llama.cpp "${spec#*:}")"
  if [ -z "$u" ]; then bad "llama.cpp ($sub)" "no release asset found"; continue; fi
  fetch "$u" "$E/$sub.tar.gz" && real && [ "$HAVE_TAR" = 1 ] && { mkdir -p "$E/$sub"; tar -xzf "$E/$sub.tar.gz" -C "$E/$sub"; }
done
set --

# ================================================================ 2. AI models
log "=== [2/9] AI chat models (GGUF) ==="
M="$ROOT/AI-Offline/models"
fetch "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf" "$M/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
if [ "$SKIP_MODELS" = 0 ]; then
  fetch "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" "$M/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
  fetch "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf" "$M/Qwen2.5-7B-Instruct-Q4_K_M.gguf"
else log "models: large models skipped"; fi

# ================================================================ 3. GPT4All
log "=== [3/9] GPT4All (offline document Q&A) ==="
if [ "$PLAT" = mac ]; then u="$(gh_asset nomic-ai/gpt4all 'installer-macos-v.*\.dmg$' latest)"
else u="$(gh_asset nomic-ai/gpt4all 'installer-linux-v.*\.run$' latest)"; fi
if [ -n "$u" ]; then fetch "$u" "$ROOT/AI-Offline/DocReader-GPT4All/$(basename "$u")" && chmod +x "$ROOT/AI-Offline/DocReader-GPT4All/$(basename "$u")" 2>/dev/null
else bad "GPT4All" "no release asset found"; fi
else log "=== [1-3/9] Offline AI SKIPPED ==="; fi

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
    *.tar.gz) tar -xzf "$KT/$f" -C "$KT/$p" ;;
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
  log "osmand: $(wc -l < "$WORK/osmand.txt" | tr -d ' ') US map files"
  [ -s "$WORK/osmand.txt" ] || bad "OsmAnd maps" "no US maps found in the OsmAnd index"
  while IFS= read -r fn; do fetch "https://download.osmand.net/download.php?standard=yes&file=$fn" "$ROOT/OsmAnd/$fn"; done < "$WORK/osmand.txt"

  log "=== [8b] Desktop map viewer (OsmAndMapCreator + portable Java) ==="
  MVD="$ROOT/OsmAnd/MapViewer-Desktop"
  if [ "$HAVE_UNZIP" = 1 ]; then
    fetch "https://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip" "$MVD/OsmAndMapCreator.zip" &&
      real && unzip -o -q "$MVD/OsmAndMapCreator.zip" -d "$MVD/app"
    jos="$PLAT"; [ "$PLAT" = linux ] || jos=mac
    if fetch "https://api.adoptium.net/v3/binary/latest/21/ga/${jos}/${JARCH}/jre/hotspot/normal/eclipse" "$MVD/jre.tar.gz" && real; then
      mkdir -p "$MVD/_jre"; tar -xzf "$MVD/jre.tar.gz" -C "$MVD/_jre" 2>/dev/null
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

# ================================================================ launchers (AI)
if [ "$SKIP_AI" = 0 ]; then
log "=== Writing AI launchers ==="
AO="$ROOT/AI-Offline"
make_launcher(){ # file model extra-args
cat > "$AO/$1" <<EOS
#!/usr/bin/env bash
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
CLI="\$(find "\$DIR/engine" -name llama-cli -type f 2>/dev/null | head -n1)"
[ -z "\$CLI" ] && { echo "AI engine not found in \$DIR/engine"; exit 1; }
LIBDIR="\$(dirname "\$CLI")"
export LD_LIBRARY_PATH="\$LIBDIR:\${LD_LIBRARY_PATH:-}"
export DYLD_LIBRARY_PATH="\$LIBDIR:\${DYLD_LIBRARY_PATH:-}"
exec "\$CLI" -m "\$DIR/models/$2" -c 4096 $3 -cnv
EOS
chmod +x "$AO/$1" 2>/dev/null
}
make_launcher "chat-3B-light.sh" "Llama-3.2-3B-Instruct-Q4_K_M.gguf" ""
make_launcher "chat-8B-smart.sh" "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" ""
if [ "$PLAT" = linux ]; then
  cat > "$AO/chat-GPU-Qwen7B.sh" <<'EOS'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="$(find "$DIR/engine/gpu" -name llama-cli -type f 2>/dev/null | head -n1)"
[ -z "$CLI" ] && CLI="$(find "$DIR/engine" -name llama-cli -type f 2>/dev/null | head -n1)"
LIBDIR="$(dirname "$CLI")"; export LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}"
exec "$CLI" -m "$DIR/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf" -c 4096 -ngl 99 -cnv
EOS
  chmod +x "$AO/chat-GPU-Qwen7B.sh" 2>/dev/null
fi
cat > "$AO/web-ui.sh" <<'EOS'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
SRV="$(find "$DIR/engine" -name llama-server -type f 2>/dev/null | head -n1)"
[ -z "$SRV" ] && { echo "server not found"; exit 1; }
LIBDIR="$(dirname "$SRV")"; export LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}"; export DYLD_LIBRARY_PATH="$LIBDIR:${DYLD_LIBRARY_PATH:-}"
echo "Open http://127.0.0.1:8080 when it says 'server listening'"
exec "$SRV" -m "$DIR/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096 --host 127.0.0.1 --port 8080
EOS
chmod +x "$AO/web-ui.sh" 2>/dev/null
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
place_doc "HOW-TO-ASK-YOUR-DOCS"  "$ROOT/AI-Offline/DocReader-GPT4All/HOW-TO-ASK-YOUR-DOCS"
place_doc "HOW-TO-USE-KIWIX"      "$ROOT/Kiwix-Reader/HOW-TO-USE-KIWIX"
place_doc "Manuals-READ-ME-FIRST" "$ROOT/Manuals/READ-ME-FIRST"
place_doc "Medical-READ-ME-FIRST" "$ROOT/Medical/READ-ME-FIRST"
place_doc "RADIO-GUIDE"           "$ROOT/Manuals/Radio-Communications/RADIO-GUIDE"
place_doc "HOW-TO-VIEW-MAPS"      "$ROOT/OsmAnd/HOW-TO-VIEW-MAPS"
place_doc "USE-ON-PHONE"          "$ROOT/Phone-Apps/USE-ON-PHONE"
for f in OPEN-LIBRARY.command OPEN-LIBRARY.sh OPEN-LIBRARY.bat CHECK-DRIVE.command CHECK-DRIVE.sh CHECK-DRIVE.bat check-drive.ps1; do
  place "drive/$f" "$ROOT/$f"
done
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
  mc=$(find "$ROOT/OsmAnd" -maxdepth 1 -type f -name '*.obf.zip' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$mc" -gt 0 ]; then
    printf '%s' "<h2>&#128451; Maps</h2><table><tr><th>Item</th><th>Folder</th><th>Size</th></tr>"
    printf '%s' "<tr><td>Offline US maps - $mc files</td><td class='muted'>OsmAnd</td><td>$(du -ch "$ROOT"/OsmAnd/*.obf.zip 2>/dev/null | tail -1 | cut -f1)</td></tr></table>"
  fi
  printf '%s' "</div></body></html>"
} > "$IDX"

# ================================================================ checksums
# One fingerprint per file, so CHECK-DRIVE can prove nothing has rotted.
# Same format on every OS: "<lowercase sha256>  ./path/with/forward/slashes".
log "=== Fingerprinting every file (SHA256SUMS.txt) - this takes a while ==="
( cd "$ROOT" && find . -type f \
    ! -name 'SHA256SUMS.txt*' ! -name '._*' ! -name '.DS_Store' ! -name '*.part' ! -name '*.sha256' ! -name '_*' \
    ! -path './.Spotlight-V100/*' ! -path './.fseventsd/*' ! -path './.Trashes/*' ! -path './System Volume Information/*' |
  LC_ALL=C sort | while IFS= read -r f; do $SHA "$f" || echo "HASHFAIL $f" >&2; done ) > "$ROOT/SHA256SUMS.txt.new" 2> "$WORK/hashfail.txt"
if [ -s "$WORK/hashfail.txt" ]; then bad "checksums" "could not read: $(tr '\n' ' ' < "$WORK/hashfail.txt")"; fi
mv -f "$ROOT/SHA256SUMS.txt.new" "$ROOT/SHA256SUMS.txt"
log "SHA256SUMS.txt: $(wc -l < "$ROOT/SHA256SUMS.txt" | tr -d ' ') files"

# Compare each ZIM with the SHA-256 that Kiwix publishes for it.
log "=== Checking archives against Kiwix's published fingerprints ==="
zok=0; znone=0
while IFS= read -r s; do
  z="${s%.sha256}"; rel="./${z#"$ROOT"/}"
  want="$(awk '{print $1; exit}' "$s" | tr 'A-F' 'a-f')"
  got="$(awk -v p="$rel" 'substr($0, 67) == p {print $1; exit}' "$ROOT/SHA256SUMS.txt")"
  if [ -n "$want" ] && [ "$want" = "$got" ]; then zok=$((zok+1))
  elif [ -n "$want" ] && [ -f "$z" ]; then bad "$(basename "$z")" "does not match Kiwix's fingerprint (damaged download). Deleted it - run the script again."; rm -f "$z"
  fi
done < <(find "$ROOT" -type f -name '*.zim.sha256' ! -name '._*')
while IFS= read -r z; do [ -f "$z.sha256" ] || znone=$((znone+1)); done < <(find "$ROOT" -type f -name '*.zim' ! -name '._*')
log "archives matching Kiwix's fingerprint: $zok   (no published fingerprint: $znone)"

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

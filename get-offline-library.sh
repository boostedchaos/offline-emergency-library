#!/usr/bin/env bash
# get-offline-library.sh — Mac/Linux one-shot downloader for the Offline Emergency Library.
# Mirrors Get-OfflineLibrary.ps1. Resumable: re-run to continue after an interruption.
#
# Usage:
#   ./get-offline-library.sh                 # asks where to save
#   ./get-offline-library.sh -d /mnt/usb     # non-interactive
#   flags: --lite  --skip-wikipedia  --skip-maps  --skip-models

REPO_RAW="https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main"
DEST=""; SKIP_WIKI=0; SKIP_MAPS=0; SKIP_MODELS=0; LITE=0
REGION="US"; LISTREGIONS=0; FILTER=""
EDU=0; EDULANG="en"; KOLIBRI=0
CONTINENTS="africa asia australia-oceania centralamerica europe northamerica southamerica"
# Map common names / ISO codes to the OsmAnd region token. Unknown input passes through.
alias_region(){
  t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  case "$t" in
    us|usa|u.s.|u.s.a.|america|united-states|unitedstates) echo "US";;
    uk|gb|gbr|britain|great-britain|england|united-kingdom) echo "Gb";;
    deu|ger|germany) echo "Germany";;
    fra|france) echo "France";;
    esp|spain) echo "Spain";;
    ita|italy) echo "Italy";;
    nld|holland|netherlands) echo "Netherlands";;
    che|swiss|switzerland) echo "Switzerland";;
    aut|austria) echo "Austria";;
    bel|belgium) echo "Belgium";;
    prt|portugal) echo "Portugal";;
    irl|ireland) echo "Ireland";;
    swe|sweden) echo "Sweden";;
    nor|norway) echo "Norway";;
    dnk|denmark) echo "Denmark";;
    fin|finland) echo "Finland";;
    pol|poland) echo "Poland";;
    cze|czech|czechia|czech-republic) echo "Czech-republic";;
    grc|greece) echo "Greece";;
    can|canada) echo "Canada";;
    mex|mexico) echo "Mexico";;
    bra|brazil) echo "Brazil";;
    arg|argentina) echo "Argentina";;
    nzl|new-zealand) echo "New-zealand";;
    jpn|japan) echo "Japan";;
    kor|korea|south-korea) echo "South-korea";;
    chn|china) echo "China";;
    ind|india) echo "India";;
    idn|indonesia) echo "Indonesia";;
    rus|russia) echo "Russia";;
    zaf|south-africa) echo "South-africa";;
    ken|kenya) echo "Kenya";;
    egy|egypt) echo "Egypt";;
    nga|nigeria) echo "Nigeria";;
    tur|turkey|turkiye) echo "Turkey";;
    sau|saudi|saudi-arabia) echo "Saudi-arabia";;
    are|uae|united-arab-emirates) echo "United-arab-emirates";;
    *) echo "$1";;
  esac
}
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--destination) DEST="$2"; shift 2;;
    --region)         REGION="$2"; shift 2;;
    --list-regions)   LISTREGIONS=1; if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then FILTER="$2"; shift 2; else shift; fi;;
    --education)      EDU=1; shift;;
    --edu-lang)       EDULANG="$2"; shift 2;;
    --kolibri)        KOLIBRI=1; shift;;
    --lite)           LITE=1; shift;;
    --skip-wikipedia) SKIP_WIKI=1; shift;;
    --skip-maps)      SKIP_MAPS=1; shift;;
    --skip-models)    SKIP_MODELS=1; shift;;
    --no-aria)        NO_ARIA=1; shift;;
    *) shift;;
  esac
done
if [ "$LITE" = 1 ]; then SKIP_WIKI=1; SKIP_MODELS=1; fi

command -v curl >/dev/null 2>&1 || { echo "ERROR: 'curl' is required."; exit 1; }
HAVE_UNZIP=1; command -v unzip >/dev/null 2>&1 || HAVE_UNZIP=0
HAVE_TAR=1;   command -v tar   >/dev/null 2>&1 || HAVE_TAR=0

# ---- --list-regions (discovery, no download) ----
if [ "$LISTREGIONS" = 1 ]; then
  idx="$(mktemp 2>/dev/null || echo /tmp/osmidx.xml)"
  curl -sL "https://download.osmand.net/get_indexes" -o "$idx"
  names="$(grep -oE 'name="[^"]+\.obf\.zip"' "$idx" | sed -E 's/name="([^"]+)"/\1/' | grep -viE 'wiki|srtm|depth|road|hillshade|heightmap')"
  if [ -n "$FILTER" ]; then
    echo "Regions / sub-regions matching '$FILTER' (pass any of these to --region):"
    echo "$names" | grep -iE "$FILTER" | sed -E "s/_(africa|asia|australia-oceania|centralamerica|europe|northamerica|southamerica)_[0-9]+\.obf\.zip\$//" | sort -u | sed 's/^/  /'
  else
    echo "Available top-level regions (pass one to --region, e.g. --region France):"
    echo "$names" | cut -d_ -f1 | sort | uniq -c | awk '{printf "  %-26s %s file(s)\n",$2,$1}'
    echo ""
    echo "Continents: $CONTINENTS, or 'world' for everything."
    echo "To see a country's sub-regions:  --list-regions US"
  fi
  rm -f "$idx" 2>/dev/null; exit 0
fi

if [ -z "$DEST" ]; then
  # When run as `curl ... | bash`, stdin is the script itself — read the answer from the
  # terminal instead, or tell the user to pass -d if there's no terminal.
  # `[ -r /dev/tty ]` is true even with no controlling terminal (cron/CI/ssh non-tty),
  # so actually try to open it; otherwise the read errors and the friendly message below
  # is skipped.
  if ( : < /dev/tty ) 2>/dev/null; then
    echo ""
    echo "  Offline Emergency Library installer"
    echo "  -----------------------------------"
    printf "Where would you like to save these files? "
    read -r DEST < /dev/tty
  else
    echo "No destination given and no terminal to prompt."
    echo "Re-run with a path, e.g.:  bash get-offline-library.sh -d /path/to/drive"
    exit 1
  fi
fi
[ -z "$DEST" ] && { echo "No destination given. Exiting."; exit 1; }
ROOT="$DEST/OfflineLibrary"
mkdir -p "$ROOT" || { echo "Cannot create $ROOT"; exit 1; }
LOG="$ROOT/_download.log"
log(){ printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
# Big-file downloader: use aria2 (multi-connection, resumable) when available for a big
# speed-up, otherwise fall back to curl. Both resume. Honor --no-aria.
USE_ARIA=0
if [ "${NO_ARIA:-0}" != "1" ] && command -v aria2c >/dev/null 2>&1; then USE_ARIA=1; fi
fetch(){ # url out
  if [ "$USE_ARIA" = 1 ]; then
    aria2c -c -x16 -s16 -k1M --max-tries=10 --retry-wait=5 --console-log-level=warn \
      --summary-interval=0 --allow-overwrite=false --auto-file-renaming=false \
      -d "$(dirname "$2")" -o "$(basename "$2")" "$1" && return 0
    echo "  (aria2 failed, falling back to curl)"
  fi
  curl -fL -C - --retry 10 --retry-delay 5 --retry-all-errors -sS -o "$2" "$1" || {
    log "ERROR: download failed: $1 -> $2. Re-run the installer to resume."
    exit 1
  }
  [ -s "$2" ] || { log "ERROR: download is missing or empty: $2"; exit 1; }
}
if [ "$USE_ARIA" = 1 ]; then log "Downloader: aria2 (fast, multi-connection)"; else log "Downloader: curl (tip: install 'aria2' for much faster downloads)"; fi
if [ "$LITE" = 1 ]; then log "Lite preset: 3B AI, medical/survival references and maps for '$REGION' (unless skipped). Size depends on region; use --region for a small area or --skip-maps. Re-run without --lite to add the full library."; fi
UA="Mozilla/5.0"

# ---- platform detection ----
OSN="$(uname -s)"; ARCHN="$(uname -m)"
case "$ARCHN" in arm64|aarch64) CPU=arm64; JARCH=aarch64;; *) CPU=x64; JARCH=x64;; esac
case "$OSN" in Darwin) PLAT=mac;; Linux) PLAT=linux;; *) PLAT=linux;; esac
log "Platform: $PLAT/$CPU   Destination: $ROOT"
[ "$HAVE_UNZIP" = 0 ] && log "NOTE: 'unzip' not found — the desktop map viewer needs it (install it to enable maps-on-PC)."

# ---- folder tree ----
for d in AI-Offline AI-Offline/engine AI-Offline/models AI-Offline/DocReader-GPT4All \
         Manuals Manuals/ArmyFieldManuals Manuals/Repair-iFixit Manuals/DIY-Appropedia \
         Manuals/Survival-Water-Food Manuals/Radio-Communications \
         Medical Medical/WikiMed Medical/zimgit-medicine Medical/Manuals-PDF \
         Wikipedia OsmAnd Kiwix-Reader Phone-Apps Education; do
  mkdir -p "$ROOT/$d"
done

# ---- helpers ----
gh_asset(){ # repo regex  -> first matching asset url across recent releases
  curl -s -H "User-Agent: oel" "https://api.github.com/repos/$1/releases?per_page=20" \
   | grep -oE '"browser_download_url"[ ]*:[ ]*"[^"]+"' | sed -E 's/.*"(https[^"]+)"/\1/' \
   | grep -E "$2" | head -n1
}
gh_asset_latest(){ # repo regex -> asset url from the 'latest' release
  curl -s -H "User-Agent: oel" "https://api.github.com/repos/$1/releases/latest" \
   | grep -oE '"browser_download_url"[ ]*:[ ]*"[^"]+"' | sed -E 's/.*"(https[^"]+)"/\1/' \
   | grep -E "$2" | head -n1
}
latest_zim(){ curl -sL -A "$UA" "$1" | grep -oE "$2[^\"<]*\.zim" | sort -u | tail -n1; }

# ================================================================ 1. AI engine
# llama.cpp for Windows, macOS and Linux, all from ONE build, so a drive made on any
# computer runs the AI on any other. Folder names match the .bat/.sh launchers below.
log "=== [1/8] Offline AI engine (llama.cpp) for Windows, macOS and Linux ==="
LLAMA_ASSETS="win-cpu-x64.zip:x64 win-cpu-arm64.zip:arm64 win-vulkan-x64.zip:vulkan-x64 macos-arm64.tar.gz:macos-arm64 macos-x64.tar.gz:macos-x64 ubuntu-x64.tar.gz:linux-x64 ubuntu-arm64.tar.gz:linux-arm64 ubuntu-vulkan-x64.tar.gz:linux-vulkan-x64"
# untar_real ARCHIVE DEST - exFAT has no symlinks (Linux cannot make them there; macOS
# writes "XSym" stand-ins only macOS can read). Unpack on the computer's own disk first,
# then copy with links followed (cp -RL) so the drive holds real files.
untar_real(){
  t="$(mktemp -d 2>/dev/null || echo "/tmp/oel-untar-$$")"; mkdir -p "$t" "$2"
  tar -xzf "$1" -C "$t" && cp -RL "$t/." "$2/"; rc=$?
  rm -rf "$t"; return $rc
}
if [ "$HAVE_TAR" = 1 ]; then
  rels="$(curl -sL -H "User-Agent: oel" "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=20")"
  urls="$(printf '%s' "$rels" | grep -oE '"browser_download_url"[ ]*:[ ]*"[^"]+"' | sed -E 's/.*"(https[^"]+)"/\1/')"
  LT=""
  for t in $(printf '%s' "$rels" | grep -oE '"tag_name"[ ]*:[ ]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/'); do
    ok=1; for x in $LLAMA_ASSETS; do printf '%s\n' "$urls" | grep -q "/download/$t/llama-$t-bin-${x%%:*}\$" || { ok=0; break; }; done
    [ "$ok" = 1 ] && { LT="$t"; break; }
  done
  if [ -z "$LT" ]; then log "engine: no recent llama.cpp build has all 8 platform files"
  else
    log "engine: llama.cpp $LT"
    E="$ROOT/AI-Offline/engine"
    for x in $LLAMA_ASSETS; do
      f="${x%%:*}"; d="$E/${x##*:}"
      log "engine: $f"; fetch "https://github.com/ggml-org/llama.cpp/releases/download/$LT/llama-$LT-bin-$f" "$E/$f"
      rm -rf "$d"; mkdir -p "$d"   # fresh unpack: no files left from an older build
      case "$f" in
        *.zip)    if [ "$HAVE_UNZIP" = 1 ]; then unzip -o -q "$E/$f" -d "$d" || log "  WARN: could not unpack $f"; else log "  $f: install 'unzip' to unpack the Windows engine"; fi ;;
        *.tar.gz) untar_real "$E/$f" "$d" || log "  WARN: could not unpack $f" ;;
      esac
    done
    echo "$LT" > "$E/BUILD.txt"
  fi
else
  log "engine: skipped (no 'tar')"
fi

# ================================================================ 2. AI models
log "=== [2/8] AI chat models (GGUF) ==="
fetch "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf" "$ROOT/AI-Offline/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
log "model: Llama-3.2-3B done"
if [ "$SKIP_MODELS" = 0 ]; then
  fetch "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" "$ROOT/AI-Offline/models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"; log "model: Llama-3.1-8B done"
  fetch "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf" "$ROOT/AI-Offline/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf"; log "model: Qwen2.5-7B done"
else
  log "models: large models skipped"
fi

# ================================================================ 3. GPT4All
log "=== [3/8] GPT4All (offline document Q&A) ==="
if [ "$LITE" = 0 ]; then
if [ "$PLAT" = mac ]; then
  u="$(gh_asset_latest nomic-ai/gpt4all 'installer-macos-v.*\.dmg$')"
  [ -n "$u" ] && { log "gpt4all: $(basename "$u")"; fetch "$u" "$ROOT/AI-Offline/DocReader-GPT4All/$(basename "$u")"; }
else
  u="$(gh_asset_latest nomic-ai/gpt4all 'installer-linux-v.*\.run$')"
  [ -n "$u" ] && { log "gpt4all: $(basename "$u")"; fetch "$u" "$ROOT/AI-Offline/DocReader-GPT4All/$(basename "$u")"; chmod +x "$ROOT/AI-Offline/DocReader-GPT4All/$(basename "$u")" 2>/dev/null; }
fi
else log "gpt4all: skipped (lite preset)"; fi

# ================================================================ 4. Kiwix reader
log "=== [4/8] Kiwix reader ==="
if [ "$PLAT" = linux ] && [ "$CPU" = x64 ]; then
  ai="$(curl -sL -A "$UA" https://download.kiwix.org/release/kiwix-desktop/ | grep -oE 'kiwix-desktop_x86_64_[0-9][^\"]*\.appimage' | sort -u | tail -n1)"
  if [ -n "$ai" ]; then log "kiwix: $ai"; fetch "https://download.kiwix.org/release/kiwix-desktop/$ai" "$ROOT/Kiwix-Reader/$ai"; chmod +x "$ROOT/Kiwix-Reader/$ai" 2>/dev/null; fi
else
  log "kiwix desktop: on macOS install 'Kiwix' from the Mac App Store or kiwix.org; on Linux-ARM use the Kiwix website. (ZIMs still work via the bundled Android app or any Kiwix build.)"
fi

# ================================================================ 5. ZIM archives
log "=== [5/8] Offline archives (Kiwix ZIM) ==="
add_zim(){ n="$(latest_zim "$1" "$2")"; [ -n "$n" ] && { log "zim: $n"; fetch "$1$n" "$3/$n"; } || log "zim: not found ($2)"; }
if [ "$LITE" = 0 ]; then
  add_zim "https://download.kiwix.org/zim/ifixit/"    "ifixit_en_all_"            "$ROOT/Manuals/Repair-iFixit"
  add_zim "https://download.kiwix.org/zim/other/"     "appropedia_en_all_maxi_"   "$ROOT/Manuals/DIY-Appropedia"
fi
add_zim "https://download.kiwix.org/zim/other/"     "zimgit-post-disaster_en_"  "$ROOT/Manuals/Survival-Water-Food"
add_zim "https://download.kiwix.org/zim/other/"     "zimgit-water_en_"          "$ROOT/Manuals/Survival-Water-Food"
add_zim "https://download.kiwix.org/zim/other/"     "zimgit-food-preparation_en_" "$ROOT/Manuals/Survival-Water-Food"
add_zim "https://download.kiwix.org/zim/other/"     "zimgit-knots_en_"          "$ROOT/Manuals/Survival-Water-Food"
add_zim "https://download.kiwix.org/zim/wikipedia/" "wikipedia_en_medicine_maxi_" "$ROOT/Medical/WikiMed"
add_zim "https://download.kiwix.org/zim/other/"     "zimgit-medicine_en_"       "$ROOT/Medical/zimgit-medicine"

# ================================================================ 5b. Education (opt-in)
if [ "$EDU" = 1 ]; then
  log "=== [5b] Education: Khan Academy (Kiwix ZIM, ~168 GB with videos, lang=$EDULANG) ==="
  mkdir -p "$ROOT/Education/KhanAcademy"
  kaname="$(latest_zim 'https://download.kiwix.org/zim/other/' "khanacademy_${EDULANG}_all_")"
  if [ -n "$kaname" ]; then log "zim: $kaname"; fetch "https://download.kiwix.org/zim/other/$kaname" "$ROOT/Education/KhanAcademy/$kaname"
  else log "Khan Academy: no ZIM for language '$EDULANG' (try --edu-lang en|es|fr)"; fi
else
  log "=== [5b] Education (Khan Academy) not selected - add --education to include (~168 GB) ==="
fi

# ================================================================ 5c. Kolibri app (opt-in)
if [ "$KOLIBRI" = 1 ]; then
  log "=== [5c] Kolibri learning app (pick subjects + low-res in-app) ==="
  kd="$ROOT/Education/Kolibri"; mkdir -p "$kd"
  for pat in 'windows-setup\.exe$' '\.dmg$' '_all\.deb$' '\.pex$'; do
    u="$(gh_asset_latest learningequality/kolibri "$pat")"
    [ -n "$u" ] && { log "kolibri: $(basename "$u")"; fetch "$u" "$kd/$(basename "$u")"; }
  done
  ka="$(gh_asset_latest learningequality/kolibri 'universal\.apk$')"
  [ -n "$ka" ] && { mkdir -p "$ROOT/Phone-Apps"; log "kolibri apk: $(basename "$ka")"; fetch "$ka" "$ROOT/Phone-Apps/$(basename "$ka")"; }
else
  log "=== [5c] Kolibri not selected - add --kolibri to include ==="
fi

# ================================================================ 6. PDFs
log "=== [6/8] Public-domain manuals (PDF) ==="
ia_pdf(){ curl -sL -A "$UA" "https://archive.org/metadata/$1" | grep -oE '"name":"[^"]+\.pdf"' | sed -E 's/"name":"([^"]+)"/\1/' | grep -vE '_text\.pdf$' | head -n1; }
get_pdf(){ # id  localname  destdir
  f="$(ia_pdf "$1")"
  if [ -z "$f" ]; then log "pdf: none for $1"; return; fi
  enc="$(printf '%s' "$f" | sed 's/ /%20/g')"
  out="$3/$2"
  log "pdf: $2"
  fetch "https://archive.org/download/$1/$enc" "$out"
  # validate it's really a PDF; drop error pages / empties
  if [ -f "$out" ]; then
    if [ "$(head -c 4 "$out" 2>/dev/null)" != "%PDF" ]; then log "  ERROR: $2 was not a valid PDF (removed)"; rm -f "$out"; exit 1; fi
  else log "  WARN: $2 failed to download"; fi
}
AFM="$ROOT/Manuals/ArmyFieldManuals"; MPDF="$ROOT/Medical/Manuals-PDF"
get_pdf "fm-21-76-us-army-survival-manual"                    "FM 21-76 Army Survival Manual.pdf" "$AFM"
get_pdf "fm-3-05.70-survival-2002"                            "FM 3-05.70 Survival (2002).pdf" "$AFM"
get_pdf "105-page-survival-field-manual"                      "105-Page Survival Field Manual.pdf" "$AFM"
get_pdf "UsArmyFirstAidManualFm4-25.11"                       "FM 4-25.11 First Aid.pdf" "$AFM"
get_pdf "Survival-FirstAidForSoldiers-AFieldManual"          "Survival and First Aid for Soldiers.pdf" "$AFM"
get_pdf "use-and-care-of-hand-tools-and-measuring-tools-1983" "TM 9-243 Use and Care of Hand Tools.pdf" "$AFM"
get_pdf "fm-5-426-carpentry-1995"                            "FM 5-426 Carpentry.pdf" "$AFM"
get_pdf "tm-9-8000-principles-of-automotive-vehicles-1985"   "TM 9-8000 Principles of Automotive Vehicles.pdf" "$AFM"
get_pdf "u-s-army-guide-to-rigging"                          "FM 5-125 Army Guide to Rigging.pdf" "$AFM"
get_pdf "fm-90-3-desert-operations-1993"                     "FM 90-3 Desert Operations.pdf" "$AFM"
get_pdf "tm-10-412-armed-forces-recipe-service-2003"         "TM 10-412 Armed Forces Recipe Service.pdf" "$AFM"
get_pdf "where-there-is-no-doctor"                           "Where There Is No Doctor.pdf" "$MPDF"
get_pdf "where-there-is-no-dentist-web-full-book"            "Where There Is No Dentist.pdf" "$MPDF"

# ================================================================ 7. Wikipedia + Maps
if [ "$SKIP_WIKI" = 0 ]; then
  log "=== [7/8] Wikipedia (full, no images - Kiwix ZIM, ~49 GB) ==="
  wk="$(latest_zim 'https://download.kiwix.org/zim/wikipedia/' 'wikipedia_en_all_nopic_')"
  if [ -n "$wk" ]; then log "zim: $wk"; fetch "https://download.kiwix.org/zim/wikipedia/$wk" "$ROOT/Wikipedia/$wk"
  else log "Wikipedia: ZIM not found"; fi
else log "=== [7/8] Wikipedia SKIPPED ==="; fi

if [ "$SKIP_MAPS" = 0 ]; then
  log "=== [8/8] Offline maps (OsmAnd) - region: $REGION ==="
  curl -sL "https://download.osmand.net/get_indexes" -o "$ROOT/OsmAnd/_index.xml"
  allnames="$(grep -oE 'name="[^"]+\.obf\.zip"' "$ROOT/OsmAnd/_index.xml" | sed -E 's/name="([^"]+)"/\1/' | grep -viE 'wiki|srtm|depth|road|hillshade|heightmap')"
  : > "$ROOT/OsmAnd/_filelist.txt"
  # '%s\n': without a final newline, read skips the last name (default "US" got 0 maps)
  printf '%s\n' "$REGION" | tr ',;' '  ' | tr ' ' '\n' | while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    tok="$(alias_region "$tok")"
    tl="$(printf '%s' "$tok" | tr 'A-Z' 'a-z')"
    if [ "$tl" = world ]; then printf '%s\n' "$allnames" >> "$ROOT/OsmAnd/_filelist.txt"
    elif echo "$CONTINENTS" | grep -qw "$tl"; then printf '%s\n' "$allnames" | grep -iE "_${tl}_" >> "$ROOT/OsmAnd/_filelist.txt"
    else printf '%s\n' "$allnames" | grep -iE "^${tok}_" >> "$ROOT/OsmAnd/_filelist.txt"
    fi
  done
  sort -u "$ROOT/OsmAnd/_filelist.txt" -o "$ROOT/OsmAnd/_filelist.txt"
  n=$(grep -c . "$ROOT/OsmAnd/_filelist.txt" 2>/dev/null || echo 0)
  if [ "$n" = "0" ]; then
    log "osmand: no maps matched region '$REGION'. Run with --list-regions to see valid names. Skipping maps."
  else
  log "osmand: $n map files for '$REGION'"
  while IFS= read -r fn; do [ -n "$fn" ] && fetch "https://download.osmand.net/download.php?standard=yes&file=$fn" "$ROOT/OsmAnd/$fn"; done < "$ROOT/OsmAnd/_filelist.txt"
  fi

  # desktop map viewer (OsmAndMapCreator + portable Java) — use maps on a PC, no phone
  log "=== [8b] Desktop map viewer (OsmAndMapCreator + portable Java) ==="
  MVD="$ROOT/OsmAnd/MapViewer-Desktop"; mkdir -p "$MVD/app"
  if [ "$HAVE_UNZIP" = 1 ]; then
    fetch "https://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip" "$MVD/OsmAndMapCreator.zip"
    unzip -o -q "$MVD/OsmAndMapCreator.zip" -d "$MVD/app"
    jreurl="https://api.adoptium.net/v3/binary/latest/21/ga/${PLAT}/${JARCH}/jre/hotspot/normal/eclipse"
    [ "$PLAT" = mac ] && jreurl="https://api.adoptium.net/v3/binary/latest/21/ga/mac/${JARCH}/jre/hotspot/normal/eclipse"
    fetch "$jreurl" "$MVD/jre.tar.gz"
    mkdir -p "$MVD/_jre"; tar -xf "$MVD/jre.tar.gz" -C "$MVD/_jre" 2>/dev/null
    rm -rf "$MVD/jre"; mv "$MVD/_jre"/*/ "$MVD/jre" 2>/dev/null; rm -rf "$MVD/_jre"
    cat > "$MVD/VIEW-MAPS-ON-PC.sh" <<'EOS'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
# find bundled java
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
sh "$DIR/app/OsmAndMapCreator.sh" 2>/dev/null || bash "$DIR/app/OsmAndMapCreator.sh"
EOS
    chmod +x "$MVD/VIEW-MAPS-ON-PC.sh" 2>/dev/null
    find "$MVD/app" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
    find "$MVD/jre" -name java -exec chmod +x {} \; 2>/dev/null
  else
    log "desktop map viewer: skipped (install 'unzip' then re-run to enable)"
  fi
else log "=== [8/8] Maps SKIPPED ==="; fi

# ================================================================ phone apps
log "=== Phone apps (port the library to a phone) ==="
PA="$ROOT/Phone-Apps"
ku="$(gh_asset_latest kiwix/kiwix-android 'universal-standalone\.apk$')"
[ -z "$ku" ] && ku="$(gh_asset_latest kiwix/kiwix-android '\.apk$')"
[ -n "$ku" ] && { log "phone app: Kiwix $(basename "$ku")"; fetch "$ku" "$PA/$(basename "$ku")"; }
if [ "$SKIP_MAPS" = 0 ]; then
  vc="$(curl -sL -A "$UA" https://f-droid.org/api/v1/packages/net.osmand.plus | grep -oE '"suggestedVersionCode":[0-9]+' | grep -oE '[0-9]+' | head -n1)"
  [ -n "$vc" ] && { log "phone app: OsmAnd~ $vc"; fetch "https://f-droid.org/repo/net.osmand.plus_$vc.apk" "$PA/OsmAnd-$vc.apk"; }
fi

# ================================================================ launchers (.sh + .bat)
# Both kinds on every drive, so the AI starts on any computer. Get-OfflineLibrary.ps1 writes
# the same files. Each .sh picks the engine folder for the computer it runs on.
log "=== Writing launchers (.sh + .bat) ==="
AO="$ROOT/AI-Offline"
make_sh(){ # file  tool  model  gpu(0/1)  args  note
cat > "$AO/$1" <<'EOS'
#!/usr/bin/env bash
# Offline AI (macOS / Linux). Uses the engine folder for this computer.
DIR="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) P=macos-arm64 ;;
  Darwin-*) P=macos-x64 ;;
  Linux-aarch64|Linux-arm64) P=linux-arm64 ;;
  *) P=linux-x64 ;;
esac
[ "__GPU__" = 1 ] && [ "$P" = linux-x64 ] && P=linux-vulkan-x64
BIN="$(find "$DIR/engine/$P" -name __TOOL__ -type f 2>/dev/null | head -n1)"
[ -z "$BIN" ] && { echo "AI engine for this computer not found: $DIR/engine/$P"; exit 1; }
chmod +x "$BIN" 2>/dev/null
LIBDIR="$(dirname "$BIN")"
export LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="$LIBDIR:${DYLD_LIBRARY_PATH:-}"
echo "__NOTE__"
exec "$BIN" -m "$DIR/models/__MODEL__" __ARGS__
EOS
sed -i.bak -e "s|__TOOL__|$2|" -e "s|__MODEL__|$3|" -e "s|__GPU__|$4|" -e "s|__ARGS__|$5|" -e "s|__NOTE__|$6|" "$AO/$1" && rm -f "$AO/$1.bak"
chmod +x "$AO/$1" 2>/dev/null
}
make_sh "chat-3B-light.sh"   llama-cli    "Llama-3.2-3B-Instruct-Q4_K_M.gguf"      0 "-c 4096" "Offline AI - Llama 3.2 3B (light). Ctrl+C to quit."
if [ "$LITE" = 0 ]; then
make_sh "chat-8B-smart.sh"   llama-cli    "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" 0 "-c 4096" "Offline AI - Llama 3.1 8B (smart). Ctrl+C to quit."
make_sh "chat-GPU-Qwen7B.sh" llama-cli    "Qwen2.5-7B-Instruct-Q4_K_M.gguf"        1 "-c 4096 -ngl 99" "Offline AI - Qwen2.5 7B on the GPU (Metal on a Mac, Vulkan on Linux)."
fi
make_sh "web-ui.sh"          llama-server "Llama-3.2-3B-Instruct-Q4_K_M.gguf"      0 "-c 4096 --host 127.0.0.1 --port 8080" "Open http://127.0.0.1:8080 when it says 'server is listening'."
# .bat launchers: same text as Get-OfflineLibrary.ps1 writes, with Windows (CRLF) line ends.
make_bat(){ # file  title  exe  model  args  [note]
  { echo "@echo off"; echo "title $2"; echo 'cd /d "%~dp0"'
    [ -n "$6" ] && printf '%s\n' "$6"
    echo "\"%~dp0$3\" -m \"%~dp0models\\$4\" $5"; echo "pause"; } | sed 's/$/\r/' > "$AO/$1"
}
make_bat "CHAT-3B-light.bat"   "Offline AI - Llama 3.2 3B (light)" 'engine\x64\llama-cli.exe' "Llama-3.2-3B-Instruct-Q4_K_M.gguf" "-c 4096"
if [ "$LITE" = 0 ]; then
make_bat "CHAT-8B-smart.bat"   "Offline AI - Llama 3.1 8B (smart)" 'engine\x64\llama-cli.exe' "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" "-c 4096"
make_bat "CHAT-GPU-Qwen7B.bat" "Offline AI - Qwen2.5 7B (GPU)"     'engine\vulkan-x64\llama-cli.exe' "Qwen2.5-7B-Instruct-Q4_K_M.gguf" "-c 4096 -ngl 99" 'echo If this errors with out-of-memory, your GPU is too small - change -ngl 99 to a lower
echo number (e.g. -ngl 20) or use a CPU launcher instead.'
fi
make_bat "WEB-UI.bat"          "Offline AI - Web UI"               'engine\x64\llama-server.exe' "Llama-3.2-3B-Instruct-Q4_K_M.gguf" "-c 4096 --host 127.0.0.1 --port 8080" 'echo When it says "server listening", open a browser to http://127.0.0.1:8080'

# ================================================================ documentation
log "=== Documentation (Markdown + HTML) ==="
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
place_doc(){ # base  destpath
  for ext in md html; do
    if [ -f "$SCRIPTDIR/docs/$1.$ext" ]; then cp "$SCRIPTDIR/docs/$1.$ext" "$2.$ext"
    else
      curl -fLsS -A "$UA" "$REPO_RAW/docs/$1.$ext" -o "$2.$ext" || {
        log "ERROR: documentation download failed: $1.$ext"; exit 1;
      }
    fi
  done
}
place_doc "START-HERE"            "$ROOT/START-HERE"
place_doc "HOW-TO-RUN-OFFLINE-AI" "$ROOT/AI-Offline/HOW-TO-RUN-OFFLINE-AI"
place_doc "HOW-TO-ASK-YOUR-DOCS"  "$ROOT/AI-Offline/DocReader-GPT4All/HOW-TO-ASK-YOUR-DOCS"
place_doc "HOW-TO-USE-KIWIX"      "$ROOT/Kiwix-Reader/HOW-TO-USE-KIWIX"
place_doc "Manuals-READ-ME-FIRST" "$ROOT/Manuals/READ-ME-FIRST"
place_doc "Medical-READ-ME-FIRST" "$ROOT/Medical/READ-ME-FIRST"
place_doc "RADIO-GUIDE"           "$ROOT/Manuals/Radio-Communications/RADIO-GUIDE"
place_doc "HOW-TO-VIEW-MAPS"      "$ROOT/OsmAnd/HOW-TO-VIEW-MAPS"
place_doc "USE-ON-PHONE"          "$ROOT/Phone-Apps/USE-ON-PHONE"
place_doc "Education-READ-ME-FIRST" "$ROOT/Education/READ-ME-FIRST"
place_doc "HOW-TO-KOLIBRI"          "$ROOT/Education/HOW-TO-KOLIBRI"

# CHECK-DRIVE scripts (#28), placed before the index so README.html lists them.
for f in CHECK-DRIVE.sh check-drive.ps1 CHECK-DRIVE.bat; do
  if [ -f "$SCRIPTDIR/drive/$f" ]; then cp "$SCRIPTDIR/drive/$f" "$ROOT/$f"
  else curl -fLsS -A "$UA" "$REPO_RAW/drive/$f" -o "$ROOT/$f" || { log "ERROR: download failed: drive/$f"; exit 1; }; fi
done
# A raw download is the LF git copy; cmd.exe wants CRLF (same as the launcher .bat files).
tr -d '\r' < "$ROOT/CHECK-DRIVE.bat" | sed 's/$/\r/' > "$ROOT/CHECK-DRIVE.bat.tmp" && mv -f "$ROOT/CHECK-DRIVE.bat.tmp" "$ROOT/CHECK-DRIVE.bat"
cp "$ROOT/CHECK-DRIVE.sh" "$ROOT/CHECK-DRIVE.command"   # macOS double-click
chmod +x "$ROOT/CHECK-DRIVE.sh" "$ROOT/CHECK-DRIVE.command" 2>/dev/null

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
  printf '%s' "<div class='hero'>Every guide, document, manual, archive, app and data file on this drive, with links.<br><span class='muted'>Generated $(date '+%Y-%m-%d %H:%M')</span></div>"
  [ -f "$ROOT/START-HERE.html" ] && printf '%s' "<p>&#128073; New here? Start with <a href='START-HERE.html'><b>START-HERE.html</b></a>.</p>"
  # guides
  printf '%s' "<h2>&#128214; Guides &amp; Documentation</h2><table><tr><th>Guide</th><th>Folder</th><th>Open</th></tr>"
  find "$ROOT" -type f -name '*.html' ! -name 'README.html' | sort | while read -r f; do
    rel="$(relp "$f")"; dir="$(dirname "$rel")"; [ "$dir" = "." ] && dir='(root)'
    mdrel="${rel%.html}.md"; ml=""; [ -f "$ROOT/$mdrel" ] && ml=" &middot; <a href='$mdrel'>md</a>"
    printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$dir</td><td><a href='$rel'>HTML</a>$ml</td></tr>"
  done
  printf '%s' "</table>"
  # pdfs
  if find "$ROOT" -type f -name '*.pdf' | grep -q .; then
    printf '%s' "<h2>&#128218; Manuals &amp; Books (PDF)</h2><table><tr><th>Document</th><th>Folder</th><th>Size</th><th>Open</th></tr>"
    find "$ROOT" -type f -name '*.pdf' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td><td><a href='$rel'>PDF</a></td></tr>"; done
    printf '%s' "</table>"
  fi
  # zims
  if find "$ROOT" -type f -name '*.zim' | grep -q .; then
    printf '%s' "<h2>&#127760; Offline Archives (ZIM &mdash; open with Kiwix)</h2><table><tr><th>Archive</th><th>Folder</th><th>Size</th><th>File</th></tr>"
    find "$ROOT" -type f -name '*.zim' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td><td><a href='$rel'>open</a></td></tr>"; done
    printf '%s' "</table>"
  fi
  # programs
  printf '%s' "<h2>&#9881; Programs &amp; Launchers</h2><table><tr><th>Item</th><th>Folder</th></tr>"
  { find "$ROOT" -type f \( -name '*.bat' -o -name '*.sh' -o -name '*.command' -o -name '*.appimage' -o -name '*.run' -o -name '*.dmg' \); find "$ROOT" -type f -name '*.exe' | grep -iE 'installer|kiwix-desktop'; } | sort -u | while read -r f; do rel="$(relp "$f")"; dir="$(dirname "$rel")"; [ "$dir" = "." ] && dir='(root)'; printf '%s' "<tr><td><a href='$rel'>$(basename "$f")</a></td><td class='muted'>$dir</td></tr>"; done
  printf '%s' "</table>"
  # apks
  if find "$ROOT" -type f -name '*.apk' | grep -q .; then
    printf '%s' "<h2>&#128241; Phone Apps (Android APK)</h2><table><tr><th>App</th><th>Folder</th><th>Size</th></tr>"
    find "$ROOT" -type f -name '*.apk' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td><a href='$rel'>$(basename "$f")</a></td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td></tr>"; done
    printf '%s' "</table>"
  fi
  # data
  if find "$ROOT" -type f \( -name '*.bz2' -o -name '*.obf.zip' \) | grep -q .; then
    printf '%s' "<h2>&#128451; Data</h2><table><tr><th>Item</th><th>Folder</th><th>Size</th></tr>"
    find "$ROOT" -type f -name '*.bz2' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td>$(basename "$f") <span class='muted'>(Wikipedia)</span></td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td></tr>"; done
    mc=$(find "$ROOT" -type f -name '*.obf.zip' | wc -l | tr -d ' ')
    [ "$mc" -gt 0 ] && printf '%s' "<tr><td>Offline US maps - $mc files</td><td class='muted'>OsmAnd</td><td>$(du -ch "$ROOT"/OsmAnd/*.obf.zip 2>/dev/null | tail -1 | cut -f1)</td></tr>"
    printf '%s' "</table>"
  fi
  printf '%s' "</div></body></html>"
} > "$IDX"
log "README.html index written."

# ================================================================ drive check (#28)
# One SHA-256 line per file, so CHECK-DRIVE can find damage later. Runs last,
# after README.html, so everything the installer wrote is covered.
log "=== Drive check list: CHECKSUMS-SHA256.txt ==="
# Format (same on every OS): "<lowercase sha256>  ./path/with/forward/slashes", byte-sorted.
# Skipped: the list itself, the log, the OsmAnd work files, unfinished downloads, OS clutter.
if command -v sha256sum >/dev/null 2>&1; then SHA="sha256sum"; else SHA="shasum -a 256"; fi
log "Hashing every file (one pass over the whole drive - this can take a while)..."
( cd "$ROOT" && find . -type f \
    ! -name 'CHECKSUMS-SHA256.txt*' ! -name '_download.log' ! -name '_filelist.txt' ! -name '_index.xml' \
    ! -name '*.part' ! -name '*.aria2' ! -name '._*' ! -name '.DS_Store' \
    ! -path './.Spotlight-V100/*' ! -path './.fseventsd/*' ! -path './.Trashes/*' ! -path './System Volume Information/*' |
  LC_ALL=C sort | while IFS= read -r f; do $SHA "$f" || echo "$f" >&2; done ) > "$ROOT/CHECKSUMS-SHA256.txt.new" 2> "$ROOT/CHECKSUMS-SHA256.txt.err"
if [ -s "$ROOT/CHECKSUMS-SHA256.txt.err" ]; then
  log "ERROR: could not read these files for the checksum list: $(tr '\n' ' ' < "$ROOT/CHECKSUMS-SHA256.txt.err")"; exit 1
fi
rm -f "$ROOT/CHECKSUMS-SHA256.txt.err"; mv -f "$ROOT/CHECKSUMS-SHA256.txt.new" "$ROOT/CHECKSUMS-SHA256.txt"
log "CHECKSUMS-SHA256.txt: $(grep -c . "$ROOT/CHECKSUMS-SHA256.txt") files. Run CHECK-DRIVE every few months."

log "=== DONE. Open README.html (full index) or START-HERE.html ==="
echo ""
echo "  Finished. Your offline library is in: $ROOT"
echo "  Open README.html for a full index, or START-HERE.html to begin."

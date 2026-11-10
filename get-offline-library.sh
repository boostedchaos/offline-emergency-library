#!/usr/bin/env bash
# get-offline-library.sh — Mac/Linux one-shot downloader for the Offline Emergency Library.
# Mirrors Get-OfflineLibrary.ps1. Resumable: re-run to continue after an interruption.
#
# Usage:
#   ./get-offline-library.sh                 # guided: asks where to save, how much, which maps (#80)
#   ./get-offline-library.sh -d /mnt/usb     # non-interactive
#   flags: --lite  --skip-wikipedia  --skip-maps  --skip-models
#   opt-in: --browser-maps   street maps in any web browser (US states, ~16.5 GB for all of the US)
#   opt-in: --extra-zims     Wikivoyage travel guide + Wikibooks textbooks (Kiwix ZIM, ~5.8 GB)
#   opt-in: --translate      offline translator (Qwen3 4B model on the AI engine, ~2.5 GB)
#   opt-in: --medlineplus    MedlinePlus plain-language health topics (public domain, ~30 MB)
#   add to a finished drive: --only <piece>[,<piece>...] -d <drive>   (#74)
#     pieces: translate medlineplus extra-zims browser-maps education kolibri wikipedia
#     downloads only those pieces; stops with a plain message if one needs something missing
#     (translate needs the AI engine). --region / --edu-lang still apply.
#   fresh install from a selection file: --select <file> -d <drive>   (#139)
#     the file names catalog.json ids and map regions, e.g.
#     {"pieces":["core","maps","medlineplus"],"regions":["US_delaware"]}
#     add --check-selection to print what it would install and stop (nothing is created).

REPO_RAW="https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main"
# Pieces --only can add to a finished drive (#74). A piece that needs something on the drive
# lists it in piece_needs as "file under OfflineLibrary|what it is called". When the component
# table (#67) lands, read both from it.
ONLY_PIECES="translate medlineplus extra-zims browser-maps education kolibri wikipedia"
piece_needs(){ case "$1" in translate) echo "AI-Offline/engine/BUILD.txt|the AI engine (the translator runs on it)";; esac; }
# Pieces a --select file can name (#139): the ids in catalog.json, in the same order, and what
# each one needs in the same selection. .github/scripts/check-catalog.sh keeps this list,
# select_needs, Get-OfflineLibrary.ps1 and catalog.json the same.
SELECT_PIECES="core gpt4all-repair models wikipedia maps browser-maps education kolibri extra-zims translate medlineplus"
select_needs(){ case "$1" in models|wikipedia) echo gpt4all-repair;; browser-maps) echo maps;; translate) echo core;; esac; }
# Size presets for the guided install (#80): the pieces in each one, in catalog order. They are
# the "presets" in catalog.json; .github/scripts/check-catalog.sh keeps them the same.
PRESET_SMALL="core maps"
PRESET_STANDARD="core gpt4all-repair models wikipedia maps"
PRESET_EVERYTHING="core gpt4all-repair models wikipedia maps browser-maps education kolibri extra-zims translate medlineplus"
GUIDE_EXTRAS="extra-zims translate medlineplus"   # the one yes/no for Small and Standard
GUIDE_US_GB=16.6   # US OsmAnd maps in GB (catalog.json maps.gb_default_us): preset sizes assume US maps
NARGS=$#; GUIDED=0; GUIDED_CMD=""
SELECT=""; SELECT_SET=0; CHECK_SEL=0; REGION_SET=0
ONLY=""; ONLY_SET=0; BM_ONLY=0
DEST=""; SKIP_WIKI=0; SKIP_MAPS=0; SKIP_MODELS=0; LITE=0
REGION="US"; LISTREGIONS=0; FILTER=""
EDU=0; EDULANG="en"; KOLIBRI=0; BROWSER_MAPS=0; EXTRA_ZIMS=0; TRANSLATE=0; MEDLINEPLUS=0
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
    aus|australia) echo "Australia-oceania";;   # OsmAnd splits it by state: Australia-oceania_<state>_*.obf.zip
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
# A flag that takes a value must have one: 'shift 2' on a last argument fails without
# shifting, and the loop would see the same flag forever (#192).
need_val(){ [ "$1" -ge 2 ] && [ -n "$3" ] && [ "${3#-}" = "$3" ] || { echo "ERROR: $2 needs $4."; exit 1; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--destination) need_val $# "$1" "${2:-}" "a folder"; DEST="$2"; shift 2;;
    --region)         need_val $# "$1" "${2:-}" "a region name (see --list-regions)"; REGION="$2"; REGION_SET=1; shift 2;;
    --select)         SELECT_SET=1; if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then SELECT="$2"; shift 2; else SELECT=""; shift; fi;;
    --check-selection) CHECK_SEL=1; shift;;
    --list-regions)   LISTREGIONS=1; if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then FILTER="$2"; shift 2; else shift; fi;;
    --education)      EDU=1; shift;;
    --edu-lang)       need_val $# "$1" "${2:-}" "a language (en, es or fr)"; EDULANG="$2"; shift 2;;
    --kolibri)        KOLIBRI=1; shift;;
    --extra-zims)     EXTRA_ZIMS=1; shift;;
    --translate)      TRANSLATE=1; shift;;
    --medlineplus)    MEDLINEPLUS=1; shift;;
    --lite)           LITE=1; shift;;
    --browser-maps)   BROWSER_MAPS=1; shift;;
    --skip-wikipedia) SKIP_WIKI=1; shift;;
    --skip-maps)      SKIP_MAPS=1; shift;;
    --skip-models)    SKIP_MODELS=1; shift;;
    --no-aria)        NO_ARIA=1; shift;;
    --only)           ONLY_SET=1; shift; while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do ONLY="$ONLY $1"; shift; done;;
    # A typo such as --skip-wikipeda must not be dropped and download what the user meant to skip.
    *) echo "ERROR: unknown option '$1'. See the usage at the top of this script."; exit 1;;
  esac
done
sel_has(){ case " $SEL_P " in *" $1 "*) return 0;; esac; return 1; }
# resolve_pieces "pieces" "regions": catalog ids -> the install flags above, then print them.
# Used by --select (#139) and the guided install (#80), so both turn pieces into flags the
# same way. Sets SEL_P, SEL_R, SEL_LIST and SAME (the flags as a command line).
resolve_pieces(){
  SEL_P="$1"; SEL_R="$2"
  LITE=0; SKIP_MODELS=0; SKIP_WIKI=0; SKIP_MAPS=0
  BROWSER_MAPS=0; EDU=0; KOLIBRI=0; EXTRA_ZIMS=0; TRANSLATE=0; MEDLINEPLUS=0
  sel_has gpt4all-repair || LITE=1
  sel_has models || SKIP_MODELS=1
  sel_has wikipedia || SKIP_WIKI=1
  sel_has maps || SKIP_MAPS=1
  if sel_has browser-maps; then BROWSER_MAPS=1; fi
  if sel_has education; then EDU=1; fi
  if sel_has kolibri; then KOLIBRI=1; fi
  if sel_has extra-zims; then EXTRA_ZIMS=1; fi
  if sel_has translate; then TRANSLATE=1; fi
  if sel_has medlineplus; then MEDLINEPLUS=1; fi
  REGION="US"; [ -n "$SEL_R" ] && REGION="$SEL_R"
  SEL_LIST=""; for p in $SELECT_PIECES; do sel_has "$p" && SEL_LIST="$SEL_LIST $p"; done
  SAME=""
  if [ "$LITE" = 1 ]; then SAME="$SAME --lite"; else
    [ "$SKIP_MODELS" = 1 ] && SAME="$SAME --skip-models"
    [ "$SKIP_WIKI" = 1 ] && SAME="$SAME --skip-wikipedia"
  fi
  if [ "$SKIP_MAPS" = 1 ]; then SAME="$SAME --skip-maps"; else SAME="$SAME --region $REGION"; fi
  [ "$BROWSER_MAPS" = 1 ] && SAME="$SAME --browser-maps"
  [ "$EDU" = 1 ] && SAME="$SAME --education"
  [ "$KOLIBRI" = 1 ] && SAME="$SAME --kolibri"
  [ "$EXTRA_ZIMS" = 1 ] && SAME="$SAME --extra-zims"
  [ "$TRANSLATE" = 1 ] && SAME="$SAME --translate"
  [ "$MEDLINEPLUS" = 1 ] && SAME="$SAME --medlineplus"
  echo "Pieces:$SEL_LIST"
  if [ "$SKIP_MAPS" = 1 ]; then echo "Regions: (no maps)"; else echo "Regions: $REGION"; fi
  RREGION="$REGION"; [ "$SKIP_MAPS" = 1 ] && RREGION="-"   # no region is resolved when maps are skipped (#167)
  echo "Resolved: lite=$LITE skip-models=$SKIP_MODELS skip-wikipedia=$SKIP_WIKI skip-maps=$SKIP_MAPS region=$RREGION browser-maps=$BROWSER_MAPS education=$EDU kolibri=$KOLIBRI extra-zims=$EXTRA_ZIMS translate=$TRANSLATE medlineplus=$MEDLINEPLUS"
  echo "Same as:$SAME"
}
# ---- --select: a fresh install from a selection file (#139) ----
# The file names catalog.json ids and map regions. They are turned into the flags above
# (--lite, --skip-*, --region, the opt-ins) and the normal install runs. Checked here,
# before anything is created or downloaded.
[ "$CHECK_SEL" = 0 ] || [ "$SELECT_SET" = 1 ] || { echo "ERROR: --check-selection needs --select <file>."; exit 1; }
if [ "$SELECT_SET" = 1 ]; then
  sel_fail(){ echo "ERROR: $*"; exit 1; }
  [ "$ONLY_SET" = 0 ] || sel_fail "--select cannot be combined with --only. --only adds pieces to a finished drive; --select builds a new one from a selection file."
  [ "$LITE$SKIP_WIKI$SKIP_MAPS$SKIP_MODELS$EDU$KOLIBRI$EXTRA_ZIMS$TRANSLATE$MEDLINEPLUS$BROWSER_MAPS$REGION_SET" = 00000000000 ] ||
    sel_fail "--select cannot be combined with --lite, --skip-*, --region or a piece flag. The selection file names the pieces and regions."
  [ -n "$SELECT" ] || sel_fail "--select needs a selection file."
  [ -f "$SELECT" ] && [ -r "$SELECT" ] || sel_fail "selection file not found: $SELECT"
  # Read the file as UTF-8 like PowerShell does. Refuse UTF-16 (FF FE / FE FF BOM) with the
  # same words, so a Mac user gets the hint instead of a raw 'tr: Illegal byte sequence' (#177).
  case "$(LC_ALL=C head -c 2 "$SELECT" | od -An -tx1 | tr -d ' \n')" in
    fffe|feff) sel_fail "$SELECT looks like UTF-16; save it as UTF-8 (both installers read the selection file as UTF-8)." ;;
  esac
  # The whole file must be exactly this shape (spaces and line breaks are ignored), so
  # nothing in it is skipped unread: {"pieces":["id",...],"regions":["name",...]}
  sel="$(LC_ALL=C tr '\t\r\n' '   ' < "$SELECT")"
  sel="${sel#$'\xef\xbb\xbf'}"   # a UTF-8 byte order mark (Notepad adds one)
  # A space between two name characters is inside a name ("co re"): not a selection file.
  LC_ALL=C grep -Eq '[A-Za-z0-9_.-] +[A-Za-z0-9_.-]' <<< "$sel" && sel="bad"
  sel="$(printf '%s' "$sel" | tr -d ' ')"
  A='\[("[A-Za-z0-9_.-]+"(,"[A-Za-z0-9_.-]+")*)?\]'
  LC_ALL=C grep -Eq "^\{(\"pieces\":$A(,\"regions\":$A)?|\"regions\":$A,\"pieces\":$A)\}\$" <<< "$sel" ||
    sel_fail "$SELECT is not a selection file. Expected: {\"pieces\":[\"core\",\"maps\"],\"regions\":[\"US_delaware\"]} (regions optional). Pieces: $SELECT_PIECES"
  SEL_P="$(printf '%s' "$sel" | sed -E 's/.*"pieces":\[([^]]*)\].*/\1/' | tr -d '"' | tr ',' ' ')"
  SEL_R=""; case "$sel" in *'"regions":'*) SEL_R="$(printf '%s' "$sel" | sed -E 's/.*"regions":\[([^]]*)\].*/\1/' | tr -d '"')";; esac
  [ -n "$SEL_P" ] || sel_fail "the selection names no pieces. Pieces: $SELECT_PIECES"
  for p in $SEL_P; do
    case " $SELECT_PIECES " in *" $p "*) ;; *) sel_fail "unknown piece '$p' in $SELECT. Pieces: $SELECT_PIECES";; esac
  done
  sel_has core || sel_fail "'core' is always installed; add \"core\" to the pieces."
  for p in $SEL_P; do for n in $(select_needs "$p"); do
    sel_has "$n" || sel_fail "'$p' needs '$n' in the same selection; add \"$n\" to the pieces."
  done; done
  [ -z "$SEL_R" ] || sel_has maps || sel_fail "the selection lists regions but not 'maps'; add \"maps\" or remove the regions."
  echo "Selection file: $SELECT"
  resolve_pieces "$SEL_P" "$SEL_R"
  [ "$CHECK_SEL" = 1 ] && { echo "Selection OK (--check-selection: nothing was created or downloaded)."; exit 0; }
fi
# ---- --only: add pieces to a finished drive (#74) ----
# Everything else the installer does (engine, models, manuals, maps, docs) is off; only the
# named pieces run. Checked here, before anything is created or downloaded.
if [ "$ONLY_SET" = 1 ]; then
  ONLY="$(printf '%s' "$ONLY" | tr 'A-Z,;' 'a-z  ' | xargs)"
  [ -n "$ONLY" ] || { echo "ERROR: --only needs at least one piece. Pieces: $ONLY_PIECES"; exit 1; }
  [ "$LITE$SKIP_WIKI$SKIP_MAPS$SKIP_MODELS$EDU$KOLIBRI$EXTRA_ZIMS$TRANSLATE$MEDLINEPLUS$BROWSER_MAPS" = 0000000000 ] ||
    { echo "ERROR: --only cannot be combined with --lite, --skip-* or a piece flag. Name the pieces after --only instead. Pieces: $ONLY_PIECES"; exit 1; }
  for p in $ONLY; do
    case " $ONLY_PIECES " in *" $p "*) ;; *) echo "ERROR: unknown piece '$p'. Pieces: $ONLY_PIECES"; exit 1;; esac
    case "$p" in
      translate) TRANSLATE=1;; medlineplus) MEDLINEPLUS=1;; extra-zims) EXTRA_ZIMS=1;;
      browser-maps) BROWSER_MAPS=1; BM_ONLY=1;; education) EDU=1;; kolibri) KOLIBRI=1;;
    esac
  done
  SKIP_MODELS=1; SKIP_MAPS=1; SKIP_WIKI=1
  case " $ONLY " in *" wikipedia "*) SKIP_WIKI=0;; esac
fi
if [ "$LITE" = 1 ]; then SKIP_WIKI=1; SKIP_MODELS=1; fi

command -v curl >/dev/null 2>&1 || { echo "ERROR: 'curl' is required."; exit 1; }
HAVE_UNZIP=1; command -v unzip >/dev/null 2>&1 || HAVE_UNZIP=0
HAVE_TAR=1;   command -v tar   >/dev/null 2>&1 || HAVE_TAR=0

# ---- --list-regions (discovery, no download) ----
if [ "$LISTREGIONS" = 1 ]; then
  idx="$(mktemp 2>/dev/null || echo /tmp/osmidx.xml)"
  curl -fsSL --retry 3 "https://download.osmand.net/get_indexes" -o "$idx" || { echo "Could not fetch the OsmAnd region index."; rm -f "$idx"; exit 1; }
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

# ---- space estimate for the chosen flags (#68) ----
# Sizes in GB (1024^3 bytes), measured on a full drive; keep them the same as in
# Get-OfflineLibrary.ps1 so both installers agree.
# space_estimate: EST (one "GB|what" line per piece) and EST_GB (the sum) for the flags set now
# and MAP_MB. The install runs it once; the guided install (#80) also runs it per preset.
est(){ EST="$EST$1|$2
"; }
space_estimate(){
  EST=""
  [ -z "$ONLY" ] && est 6.3 "core (AI engine, 3B model, medical, survival, manuals, Kiwix, phone apps)"
  [ "$SKIP_MODELS" = 0 ] && est 8.9 "8B + 7B AI models"
  [ "$LITE" = 0 ] && [ -z "$ONLY" ] && est 4.5 "GPT4All, iFixit, Appropedia"
  [ "$SKIP_WIKI" = 0 ] && est 49.1 "Wikipedia"
  [ "$SKIP_MAPS" = 0 ] && est "$(awk -v m="$MAP_MB" 'BEGIN{printf "%.1f", m/1024 + 0.5}')" "maps for '$REGION' + desktop viewer"
  if [ "$BROWSER_MAPS" = 1 ] && { [ "$SKIP_MAPS" = 0 ] || [ "$BM_ONLY" = 1 ]; }; then
    # all of the US ~15.4 GB; states ~0.4 of their OsmAnd size (#102); always + the world map
    bm=0
    for tok in $(printf '%s' "$REGION" | tr ',;' '  '); do
      tl="$(alias_region "$tok" | tr 'A-Z' 'a-z')"
      case "$tl" in us|world|northamerica) bm=all ;; us_*) [ "$bm" = all ] || bm=state ;; esac
    done
    case "$bm" in all) bmgb=15.4 ;; state) bmgb="$(awk -v m="$MAP_MB" 'BEGIN{print 0.4*m/1024}')" ;; *) bmgb=0 ;; esac
    est "$(awk -v b="$bmgb" 'BEGIN{printf "%.1f", b + 0.2}')" "browser maps"
  fi
  [ "$EDU" = 1 ] && est 168 "Khan Academy"
  [ "$EXTRA_ZIMS" = 1 ] && est 5.8 "Wikivoyage + Wikibooks"
  [ "$TRANSLATE" = 1 ] && est 2.3 "translator model"
  [ "$MEDLINEPLUS" = 1 ] && est 0.1 "MedlinePlus health topics"
  EST_GB="$(printf '%s' "$EST" | awk -F'|' '{s+=$1} END{printf "%.1f", s}')"
}

# ---- guided install (#80) ----
# With no flags at all and someone at a terminal, ask how much to install (three size presets,
# the biggest that fits is preselected), which maps, and one yes/no; then run exactly as if the
# matching flags were given (resolve_pieces, as --select does) and print them as a command.
# Any flag turns this off, and with no terminal nothing here runs.
guided_questions(){
  ask(){ printf '%s' "$1"; ans=""; read -r ans < /dev/tty || ans=""; }
  # free space where the files will go (the folder may not exist yet: use its nearest parent)
  d="$DEST"; while [ ! -d "$d" ] && [ "$d" != "$(dirname "$d")" ]; do d="$(dirname "$d")"; done
  free="$(df -Pk "$d" 2>/dev/null | awk 'NR==2{printf "%.1f", $4/1048576}')"
  MAP_MB="$(awk -v g="$GUIDE_US_GB" 'BEGIN{printf "%d", g*1024}')"
  gsize(){ resolve_pieces "$1" "" > /dev/null; space_estimate; printf '%s' "$EST_GB"; }   # run in $( ): changes nothing here
  s1="$(gsize "$PRESET_SMALL")"; s2="$(gsize "$PRESET_STANDARD")"; s3="$(gsize "$PRESET_EVERYTHING")"
  fit(){ [ -n "$free" ] && awk -v n="$1" -v f="$free" 'BEGIN{exit !(n<=f)}'; }
  pick=1; fit "$s2" && pick=2; fit "$s3" && pick=3
  [ -n "$free" ] || pick=2
  echo ""
  if [ -n "$free" ]; then echo "  Free space there: $free GB."; else echo "  Free space there: unknown (the folder could not be measured)."; fi
  echo "  How much do you want to install? Sizes include the US maps."
  printf '    1) Small       about %5s GB  AI chat (small model), medical, survival, Army manuals, maps\n' "$s1"
  printf '    2) Standard    about %5s GB  Small + Wikipedia, bigger AI models, repair and DIY guides\n' "$s2"
  printf '    3) Everything  about %5s GB  Standard + Khan Academy (168 GB), browser maps, translator,\n' "$s3"
  printf '                                   Wikivoyage, Wikibooks, MedlinePlus, Kolibri\n'
  if [ -n "$free" ] && ! fit "$s1"; then echo "  None of these fits. Pick Small, then a small map area or 'none' below."; fi
  while :; do
    ask "  Choose 1, 2 or 3 [$pick]: "
    case "$ans" in "") ans="$pick"; break;; 1|2|3) break;; *) echo "  Please type 1, 2 or 3.";; esac
  done
  preset="$ans"
  case "$preset" in 1) P="$PRESET_SMALL";; 2) P="$PRESET_STANDARD";; *) P="$PRESET_EVERYTHING";; esac
  echo ""
  echo "  Maps: press Enter for the whole US. Or type a country, a US state or a continent"
  echo "  (examples: UK, France, US_texas, Germany,Austria, Europe), or 'none' for no maps."
  while :; do
    ask "  Maps [US]: "
    case "$ans" in *[!A-Za-z0-9_.,\;\ -]*) echo "  Please use letters, numbers, '_', '-' and commas only."; continue;; esac
    R="$(printf '%s' "$ans" | tr ',;' '  ' | xargs | tr ' ' ',')"
    break
  done
  case "$(printf '%s' "$R" | tr 'A-Z' 'a-z')" in
    none|no|skip)   # no "case" inside $( ): bash 3.2 on macOS misreads it
      keep=""; for p in $P; do case "$p" in maps|browser-maps) ;; *) keep="$keep $p";; esac; done; P="$keep"; R="" ;;
    us) R="" ;;
  esac
  if [ "$preset" != 3 ]; then   # Everything has these already
    with="$(gsize "$P $GUIDE_EXTRAS")"; less="$(gsize "$P")"
    more="$(awk -v a="$with" -v b="$less" 'BEGIN{printf "%.1f", a-b}')"
    def=N; fit "$with" && def=Y
    echo ""
    while :; do
      ask "  Also add a translator, MedlinePlus health pages, Wikivoyage and Wikibooks (about $more GB)? [$def]: "
      case "$ans" in "") ans="$def"; break;; y|Y|yes|YES|Yes|n|N|no|NO|No) break;; *) echo "  Please type y or n.";; esac
    done
    case "$ans" in y|Y|yes|YES|Yes) P="$P $GUIDE_EXTRAS";; esac
  fi
  # catalog order, so the Pieces line and the command are the same every time
  sorted=""; for p in $SELECT_PIECES; do case " $P " in *" $p "*) sorted="$sorted $p";; esac; done
  echo ""
  resolve_pieces "${sorted# }" "$R"
  GUIDED=1
  GUIDED_CMD="bash get-offline-library.sh -d $(printf '%q' "$DEST")$SAME"
  echo ""
  echo "  The same install as one command (run it next time to skip these questions):"
  echo "    $GUIDED_CMD"
  echo ""
}

if [ "$LITE" = 1 ] && [ "$SKIP_MAPS" = 0 ] && [ "$SELECT_SET" = 0 ]; then
  echo "LITE MAP SIZE: maps for '$REGION' are still included. The default US maps alone are about 17 GB."
  echo "  Keep all US maps: use --lite with no --region (the default)."
  echo "  Smaller area: use --lite --region US_delaware (example); sizes vary by region."
  echo "  No maps, viewer or OsmAnd app: use --lite --skip-maps."
  echo "  List available US sub-regions: run with --list-regions US (then exit)."
  echo "  To change this selection, cancel with Ctrl+C and re-run with the flags above."
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
    if [ "$ONLY_SET" = 1 ]; then printf "Where is the drive you want to add to (the folder that holds OfflineLibrary)? "
    else printf "Where would you like to save these files? "; fi
    read -r DEST < /dev/tty
    if [ "$NARGS" = 0 ] && [ -n "$DEST" ]; then guided_questions; fi
  else
    echo "No destination given and no terminal to prompt."
    echo "Re-run with a path, e.g.:  bash get-offline-library.sh -d /path/to/drive"
    exit 1
  fi
fi
[ -z "$DEST" ] && { echo "No destination given. Exiting."; exit 1; }
ROOT="$DEST/OfflineLibrary"
if [ "$ONLY_SET" = 1 ]; then
  # A finished drive has CHECKSUMS-SHA256.txt (the installer's last step). Never build a new one here.
  [ -f "$ROOT/CHECKSUMS-SHA256.txt" ] || { echo "ERROR: no finished library found at $ROOT."; echo "  --only adds to a drive the installer has already filled. Run the installer without --only first, or fix -d."; echo "  A drive made before this installer added CHECKSUMS-SHA256.txt needs one full re-run (without --only) first."; exit 1; }
  for p in $ONLY; do
    need="$(piece_needs "$p")"; [ -n "$need" ] || continue
    [ -f "$ROOT/${need%%|*}" ] || { echo "ERROR: '$p' needs ${need#*|}, which is not on this drive (missing: ${need%%|*})."; echo "  Nothing was downloaded. Run the installer without --only to add it first."; exit 1; }
  done
fi
mkdir -p "$ROOT" || { echo "Cannot create $ROOT"; exit 1; }
LOG="$ROOT/_download.log"
log(){ printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
# Big-file downloader: use aria2 (multi-connection, resumable) when available for a big
# speed-up, otherwise fall back to curl. Both resume. Honor --no-aria.
USE_ARIA=0
if [ "${NO_ARIA:-0}" != "1" ] && command -v aria2c >/dev/null 2>&1; then USE_ARIA=1; fi
# Show a live progress meter (percent/size/speed/ETA) only when stdout is a real
# terminal; stay quiet with no TTY (cron/CI/piped) so logs don't fill with bars.
DL_TTY=0; [ -t 1 ] && DL_TTY=1
fetch(){ # url out
  if [ "$USE_ARIA" = 1 ]; then
    if [ "$DL_TTY" = 1 ]; then aria_prog="--summary-interval=1"; else aria_prog="--summary-interval=0"; fi
    # --follow-metalink=mem: download.kiwix.org answers aria2 with a Metalink; without
    # this, aria2 saves that XML at the output path, and a re-run fails "file exists".
    aria2c -c -x16 -s16 -k1M --max-tries=10 --retry-wait=5 --console-log-level=warn \
      $aria_prog --follow-metalink=mem --allow-overwrite=false --auto-file-renaming=false \
      -d "$(dirname "$2")" -o "$(basename "$2")" "$1"
    arc=$?; [ "$arc" = 0 ] && return 0
    # Stop, do not fall back to curl, when the user pressed Ctrl+C (aria2 exit 7) or aria2
    # left a part-done file: it is preallocated to full size with gaps, so 'curl -C -'
    # would see a "complete" file and keep a corrupt copy. aria2 resumes it from its
    # .aria2 control file on the next run.
    if [ "$arc" = 7 ] || [ -e "$2.aria2" ]; then
      log "ERROR: download stopped: $1 -> $2. Re-run the installer to resume."
      exit 1
    fi
    echo "  (aria2 failed, falling back to curl)"
  fi
  if [ "$DL_TTY" = 1 ]; then curl_prog="-#"; else curl_prog="-sS"; fi
  curl -fL -C - --retry 10 --retry-delay 5 --retry-all-errors $curl_prog -o "$2" "$1" || {
    log "ERROR: download failed: $1 -> $2. Re-run the installer to resume."
    exit 1
  }
  [ -s "$2" ] || { log "ERROR: download is missing or empty: $2"; exit 1; }
}
# Size of a remote file in bytes after redirects (empty if the server does not say).
remote_size(){ curl -sIL -A "${UA:-Mozilla/5.0}" "$1" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:"{n=$2} END{if(n>0)print n}'; }
# fetch_sized url out bytes [soft]: for a file whose name stays the same when the source
# publishes a new edition (#57). A file of the right size is kept. Otherwise the new
# edition goes to a part file whose name carries its size, so a re-run never resumes
# one edition into another, and it replaces the old file only once it is complete.
# With no size known, this is a plain fetch. With a 4th arg (soft), a size mismatch from
# the source changing mid-download is not fatal: it returns 1 so an optional download (the
# desktop viewer) can be skipped and the run continues (#99).
fetch_sized(){ # url out bytes [soft]
  [ -n "$3" ] || { fetch "$1" "$2"; return; }
  if [ -f "$2" ] && [ ! -e "$2.aria2" ] && [ "$(wc -c < "$2" | tr -d ' ')" = "$3" ]; then return 0; fi
  part="$2.$3.part"
  for o in "$2".*.part; do [ -e "$o" ] && [ "$o" != "$part" ] && rm -f "$o" "$o.aria2"; done
  [ -f "$2" ] && log "  re-download: $(basename "$2") (size on disk is not the source's $3 bytes)"
  fetch "$1" "$part"
  got="$(wc -c < "$part" | tr -d ' ')"
  if [ "$got" != "$3" ]; then
    rm -f "$part" "$part.aria2"
    if [ -n "${4:-}" ]; then log "  note: $(basename "$2") changed on the server mid-download ($got bytes, not $3 — the latest build was replaced). Keeping any existing copy; re-run to try again."; return 1; fi
    log "ERROR: $(basename "$2"): got $got bytes, expected $3. Re-run the installer."; exit 1
  fi
  rm -f "$2.aria2"; mv -f "$part" "$2"
}
if [ "$USE_ARIA" = 1 ]; then log "Downloader: aria2 (fast, multi-connection)"; else log "Downloader: curl (tip: install 'aria2' for much faster downloads)"; fi
[ "$SELECT_SET" = 1 ] && log "Selection from $SELECT:$SEL_LIST (same as:$SAME)"
[ "$GUIDED" = 1 ] && log "Guided install:$SEL_LIST (same as: $GUIDED_CMD)"
if [ "$LITE" = 1 ] && [ "$SELECT_SET" = 0 ] && [ "$GUIDED" = 0 ]; then log "Lite preset: 3B AI, medical/survival references and maps for '$REGION' (unless skipped). Size depends on region; use --region for a small area or --skip-maps. Re-run without --lite to add the full library."; fi
UA="Mozilla/5.0"
# Repo files fetched later (guides, map viewer, helpers) come from the commit main is on now,
# not from a main that moved during a run of several hours (#193). Falls back to main.
REPO_SHA="$(curl -fsS --retry 3 -H 'Accept: application/vnd.github.sha' -H 'User-Agent: oel' "https://api.github.com/repos/elhajahmadj/offline-emergency-library/commits/main" 2>/dev/null)"
if printf '%s' "$REPO_SHA" | grep -qE '^[0-9a-f]{40}$'; then REPO_RAW="${REPO_RAW%/main}/$REPO_SHA"; log "Repo files: commit $REPO_SHA"
else log "Repo files: main (could not look up its commit)"; fi
# get_repo path out: one file of this repo; retries a network blip, fails on a 404 or 5xx (#193).
get_repo(){ curl -fLsS --retry 3 --retry-all-errors -A "$UA" "$REPO_RAW/$1" -o "$2"; }

# ---- platform detection ----
OSN="$(uname -s)"; ARCHN="$(uname -m)"
case "$ARCHN" in arm64|aarch64) CPU=arm64; JARCH=aarch64;; *) CPU=x64; JARCH=x64;; esac
case "$OSN" in Darwin) PLAT=mac;; Linux) PLAT=linux;; *) PLAT=linux;; esac
log "Platform: $PLAT/$CPU   Destination: $ROOT"
[ "$HAVE_UNZIP" = 0 ] && log "NOTE: 'unzip' not found — the desktop map viewer needs it (install it to enable maps-on-PC)."

# ---- folder tree ----
[ -n "$ONLY" ] && log "Adding to the finished library: $ONLY (nothing else is downloaded)"
for d in AI-Offline AI-Offline/engine AI-Offline/models AI-Offline/DocReader-GPT4All \
         Manuals Manuals/ArmyFieldManuals Manuals/Repair-iFixit Manuals/DIY-Appropedia Manuals/Household-DIY Manuals/Metalworking \
         Manuals/Survival-Preparedness Manuals/Radio-Communications Manuals/Food-Preservation/USDA-Complete-Guide-to-Home-Canning-2015 Manuals/Food-Growing \
         Medical Medical/WikiMed Medical/Manuals-PDF Medical/Natural-Medicine Medical/Emergency-Childbirth \
         Wikipedia OsmAnd Kiwix-Reader Phone-Apps Education; do
  [ -z "$ONLY" ] && mkdir -p "$ROOT/$d"
done

# ---- OsmAnd map files for --region, picked now so the space estimate below knows their size ----
MAP_MB=0
if [ "$SKIP_MAPS" = 0 ] || [ "$BM_ONLY" = 1 ]; then   # --only browser-maps needs the sizes for its estimate, not the maps
  MAP_LOOKUP="$ROOT/OsmAnd"
  if [ "$BM_ONLY" = 1 ]; then
    # The estimate must not replace another region's OsmAnd metadata (#125).
    MAP_LOOKUP="$(mktemp -d)" || exit 1
    trap 'rm -rf "$MAP_LOOKUP"' EXIT
  else
    mkdir -p "$MAP_LOOKUP"
  fi
  curl -fsSL --retry 3 "https://download.osmand.net/get_indexes" -o "$MAP_LOOKUP/_index.xml" || : > "$MAP_LOOKUP/_index.xml"
  allnames="$(grep -oE 'name="[^"]+\.obf\.zip"' "$MAP_LOOKUP/_index.xml" | sed -E 's/name="([^"]+)"/\1/' | grep -viE 'wiki|srtm|depth|road|hillshade|heightmap')"
  : > "$MAP_LOOKUP/_filelist.txt"
  # '%s\n': without a final newline, read skips the last name (default "US" got 0 maps)
  printf '%s\n' "$REGION" | tr ',;' '  ' | tr ' ' '\n' | while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    raw="$(printf '%s' "$tok" | tr 'A-Z' 'a-z')"
    tok="$(alias_region "$tok")"
    tl="$(printf '%s' "$tok" | tr 'A-Z' 'a-z')"
    if [ "$tl" = world ]; then printf '%s\n' "$allnames" >> "$MAP_LOOKUP/_filelist.txt"
    # The typed word must be a whole continent name: grep -w also took "australia" or "oceania"
    # (part of australia-oceania), and the Australia alias is a map-name prefix, not the continent.
    elif case " $CONTINENTS " in *" $raw "*) true;; *) false;; esac; then printf '%s\n' "$allnames" | grep -iE "_${tl}_" >> "$MAP_LOOKUP/_filelist.txt"
    else printf '%s\n' "$allnames" | grep -iE "^${tok}_" >> "$MAP_LOOKUP/_filelist.txt"
    fi
  done
  sort -u "$MAP_LOOKUP/_filelist.txt" -o "$MAP_LOOKUP/_filelist.txt"
  # sum containerSize (bytes) of the picked files; one <region .../> per line in the index
  MAP_MB="$(sed -nE 's/.*containerSize="([0-9]+)".* name="([^"]+\.obf\.zip)".*/\2 \1/p' "$MAP_LOOKUP/_index.xml" |
    awk 'NR==FNR{w[$1]=1; next} ($1 in w){s+=$2} END{printf "%d", s/1048576}' "$MAP_LOOKUP/_filelist.txt" -)"
  # Maps were asked for but none matched: stop now, not after hours of other downloads (#192).
  if [ "$SKIP_MAPS" = 0 ] && ! grep -q . "$MAP_LOOKUP/_filelist.txt"; then
    if [ -z "$allnames" ]; then log "ERROR: could not read the OsmAnd map index (download.osmand.net). Check the connection and re-run, or use --skip-maps."
    else log "ERROR: no maps matched region '$REGION'. Run with --list-regions to see valid names, or use --skip-maps."; fi
    log "  Nothing was downloaded."; exit 1
  fi
  if [ "$BM_ONLY" = 1 ]; then
    rm -rf "$MAP_LOOKUP"
    trap - EXIT
  fi
fi

# ---- space estimate for the chosen flags (#68): space_estimate, defined above ----
space_estimate
FREE_GB="$(df -Pk "$ROOT" 2>/dev/null | awk 'NR==2{printf "%.1f", $4/1048576}')"
# Folder bytes do not prove this selection's downloads are complete: they can be
# unrelated files, old editions, unpacked maps or preallocated partial files (#102).
NEED_GB="$EST_GB"
log "Space estimate for this selection: about $EST_GB GB"
printf '%s' "$EST" | while IFS='|' read -r g n; do log "$(awk -v g="$g" -v n="$n" 'BEGIN{printf "  %6.1f GB  %s", g, n}')"; done
[ "$KOLIBRI" = 1 ] && log "     (Kolibri content is not counted: you pick it in the app)"
if [ -n "$FREE_GB" ]; then
  log "Conservative space budget: $NEED_GB GB. Free: $FREE_GB GB."
  log "Existing files are not subtracted; a re-run may need less space."
  if awk -v n="$NEED_GB" -v f="$FREE_GB" 'BEGIN{exit !(n>f)}'; then
    log "WARNING: NOT ENOUGH SPACE for the full selection. Budget about $NEED_GB GB, but only $FREE_GB GB is free."
    log "  Use a bigger drive, free up space, or choose less: --lite, --skip-wikipedia (49 GB), --skip-models (9 GB),"
    log "  a smaller --region, --skip-maps, or leave off an opt-in."
    # Wait for an answer when someone is at a terminal; with none (cron, CI), carry on as before (#192).
    if ( : < /dev/tty ) 2>/dev/null; then
      printf "Continue anyway? (y/N) "; ans=""; read -r ans < /dev/tty
      case "$ans" in y|Y|yes|YES|Yes) log "  Continuing at the user's request." ;; *) log "Stopped: not enough space. Nothing was downloaded."; exit 1 ;; esac
    fi
  fi
fi

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
if [ -n "${ONLY:-}" ]; then   # --only adds pieces to a finished drive: no engine download (#74)
  log "engine: not touched (--only)"
elif [ "$HAVE_TAR" = 1 ]; then
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
      # The build tag is in the file name: a re-run on a newer build must not resume into
      # the old build's archive (curl -C - / aria2 -c would append to it - see #35).
      f="${x%%:*}"; d="$E/${x##*:}"; a="$E/$LT-$f"
      log "engine: $f"; fetch "https://github.com/ggml-org/llama.cpp/releases/download/$LT/llama-$LT-bin-$f" "$a"
      rm -rf "$d"; mkdir -p "$d"   # fresh unpack: no files left from an older build
      case "$f" in
        *.zip)    if [ "$HAVE_UNZIP" = 1 ]; then unzip -o -q "$a" -d "$d" || { log "ERROR: could not unpack $f ($a). Delete it and re-run."; exit 1; }; else log "  $f: install 'unzip' to unpack the Windows engine"; fi ;;
        *.tar.gz) untar_real "$a" "$d" || { log "ERROR: could not unpack $f ($a). Delete it and re-run."; exit 1; } ;;
      esac
      # A damaged archive can unpack to nothing without an error (PowerShell 5.1 does, #35): check the program is there.
      case "$f" in *.zip) [ "$HAVE_UNZIP" = 1 ] || continue ;; esac
      [ -n "$(find "$d" -type f \( -name llama-cli -o -name llama-cli.exe \) | head -n 1)" ] || { log "ERROR: unpacked $f ($a), but llama-cli is not in it. Delete it and re-run."; exit 1; }
    done
    # Archives from other builds (and the old names without a tag) are no longer needed.
    for o in "$E"/*.zip "$E"/*.tar.gz; do
      [ -f "$o" ] || continue
      case "$(basename "$o")" in "$LT-"*) ;; *) rm -f "$o" ;; esac
    done
    echo "$LT" > "$E/BUILD.txt"
  fi
else
  log "engine: skipped (no 'tar')"
fi

# ================================================================ 2. AI models
log "=== [2/8] AI chat models (GGUF) ==="
HF="https://huggingface.co/bartowski"
M3B="$HF/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
M8B="$HF/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
MQ7="$HF/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf"
TR_MODEL="Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
MTR="$HF/Qwen_Qwen3-4B-Instruct-2507-GGUF/resolve/main/$TR_MODEL"
GGUF_URLS="$M3B $M8B $MQ7 $MTR"   # for the self-check (only files on the drive are checked)
if [ -z "$ONLY" ]; then fetch "$M3B" "$ROOT/AI-Offline/models/${M3B##*/}"; log "model: Llama-3.2-3B done"; fi
if [ "$SKIP_MODELS" = 0 ]; then
  fetch "$M8B" "$ROOT/AI-Offline/models/${M8B##*/}"; log "model: Llama-3.1-8B done"
  fetch "$MQ7" "$ROOT/AI-Offline/models/${MQ7##*/}"; log "model: Qwen2.5-7B done"
else
  log "models: large models skipped"
fi
# Translator (opt-in): one small multilingual model run by the same engine, so no new runtime.
if [ "$TRANSLATE" = 1 ]; then
  fetch "$MTR" "$ROOT/AI-Offline/models/$TR_MODEL"; log "model (translator): $TR_MODEL done"
else
  log "=== Translator not selected - add --translate to include (~2.5 GB) ==="
fi

# ================================================================ 3. GPT4All
log "=== [3/8] GPT4All (offline document Q&A) ==="
if [ -n "$ONLY" ]; then log "gpt4all: not touched (--only)"
elif [ "$LITE" = 0 ]; then
if [ "$PLAT" = mac ]; then
  u="$(gh_asset_latest nomic-ai/gpt4all 'installer-macos-v.*\.dmg$')"
  [ -n "$u" ] && { log "gpt4all: $(basename "$u")"; fetch "$u" "$ROOT/AI-Offline/DocReader-GPT4All/$(basename "$u")"; }
else
  u="$(gh_asset_latest nomic-ai/gpt4all 'installer-linux-v.*\.run$')"
  [ -n "$u" ] && { log "gpt4all: $(basename "$u")"; fetch "$u" "$ROOT/AI-Offline/DocReader-GPT4All/$(basename "$u")"; chmod +x "$ROOT/AI-Offline/DocReader-GPT4All/$(basename "$u")" 2>/dev/null; }
fi
else
  log "gpt4all: skipped (lite preset)"
  printf '%s\n' \
    "GPT4All (offline document Q&A) is NOT included in a --lite install." \
    "" \
    "This lite drive includes the source-citing manual reader:" \
    "  AI-Offline/Manual-QA/start-docs.command (macOS) or start-docs.sh (Linux)" \
    "It uses the 3B model and downloaded source text. Check the original PDF before acting." \
    "" \
    "To add GPT4All and its source-citing LocalDocs workflow:" \
    "  - re-run the installer into this same drive WITHOUT --lite, or" \
    "  - install GPT4All from gpt4all.io while you still have internet." \
    "See HOW-TO-ASK-YOUR-DOCS.html in this folder." \
    > "$ROOT/AI-Offline/DocReader-GPT4All/GPT4All-NOT-INCLUDED-IN-LITE.txt"
fi

# ================================================================ 4. Kiwix reader
log "=== [4/8] Kiwix reader ==="
if [ -n "$ONLY" ]; then log "kiwix: not touched (--only)"
elif [ "$PLAT" = linux ] && [ "$CPU" = x64 ]; then
  ai="$(curl -sL -A "$UA" https://download.kiwix.org/release/kiwix-desktop/ | grep -oE 'kiwix-desktop_x86_64_[0-9][^\"]*\.appimage' | sort -u | tail -n1)"
  if [ -n "$ai" ]; then log "kiwix: $ai"; fetch "https://download.kiwix.org/release/kiwix-desktop/$ai" "$ROOT/Kiwix-Reader/$ai"; chmod +x "$ROOT/Kiwix-Reader/$ai" 2>/dev/null; fi
else
  log "kiwix desktop: on macOS install 'Kiwix' from the Mac App Store or kiwix.org; on Linux-ARM use the Kiwix website. (ZIMs still work via the bundled Android app or any Kiwix build.)"
fi

# ================================================================ 5. ZIM archives
log "=== [5/8] Offline archives (Kiwix ZIM) ==="
add_zim(){ n="$(latest_zim "$1" "$2")"; [ -n "$n" ] && { log "zim: $n"; fetch "$1$n" "$3/$n"; } || log "zim: not found ($2)"; }
if [ -n "$ONLY" ]; then log "zim: core archives not touched (--only)"; else
if [ "$LITE" = 0 ]; then
  add_zim "https://download.kiwix.org/zim/ifixit/"    "ifixit_en_all_"            "$ROOT/Manuals/Repair-iFixit"
  add_zim "https://download.kiwix.org/zim/other/"     "appropedia_en_all_maxi_"   "$ROOT/Manuals/DIY-Appropedia"
fi
# NOTE: the zimgit-* collections (post-disaster, water, food-preparation, knots, medicine)
# were removed in #122: they are collections of third-party PDFs with no stated license, and
# some items are all rights reserved (e.g. the SAS Survival Handbook, Foxfire). This kit only
# ships content that is free, openly licensed, or public domain. Survival/water/food/first-aid
# are covered by the Army field manuals, USDA canning guide, Appropedia, WikiMed and the
# Hesperian/WHO PDFs. A license-cleared replacement for knots is tracked in #78.
add_zim "https://download.kiwix.org/zim/wikipedia/" "wikipedia_en_medicine_maxi_" "$ROOT/Medical/WikiMed"
fi

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

# ================================================================ 5d. Extra archives (opt-in)
# Wikivoyage (travel guide, ~1.1 GB) + Wikibooks (open textbooks, ~4.7 GB), both CC BY-SA.
# WikiHow is not included: download.kiwix.org no longer publishes it.
if [ "$EXTRA_ZIMS" = 1 ]; then
  log "=== [5d] Extra archives: Wikivoyage + Wikibooks (Kiwix ZIM, ~5.8 GB) ==="
  mkdir -p "$ROOT/Extra-Archives/Wikivoyage" "$ROOT/Extra-Archives/Wikibooks"
  add_zim "https://download.kiwix.org/zim/wikivoyage/" "wikivoyage_en_all_maxi_" "$ROOT/Extra-Archives/Wikivoyage"
  add_zim "https://download.kiwix.org/zim/wikibooks/"  "wikibooks_en_all_maxi_"  "$ROOT/Extra-Archives/Wikibooks"
else
  log "=== [5d] Extra archives (Wikivoyage + Wikibooks) not selected - add --extra-zims to include (~5.8 GB) ==="
fi

# ================================================================ 5e. MedlinePlus (opt-in)
# Plain-language health topic summaries (English + Spanish) from the US National Library of
# Medicine's daily XML file: public domain. Only the summaries: the MedlinePlus encyclopedia
# (A.D.A.M.) and drug pages (ASHP) are copyrighted, so the Kiwix MedlinePlus ZIM is not used.
# The XML goes inside one offline page (medlineplus/MedlinePlus.html) that lists and searches it.
if [ "$MEDLINEPLUS" = 1 ]; then
  log "=== [5e] MedlinePlus health topics (public domain, ~30 MB) ==="
  md="$ROOT/Medical/MedlinePlus"; mkdir -p "$md"
  mx="$(curl -sL -A "$UA" 'https://medlineplus.gov/xml.html' | grep -oE 'mplus_topics_[0-9]{4}-[0-9]{2}-[0-9]{2}\.xml' | sort -u | tail -n1)"
  if [ -n "$mx" ]; then
    log "medlineplus: $mx"; fetch "https://medlineplus.gov/xml/$mx" "$md/$mx"
    # '</script' would end the data block early; real topic XML never has it (all HTML is escaped).
    if [ "$(head -c 5 "$md/$mx")" != "<?xml" ] || ! grep -q '<health-topics' "$md/$mx" || grep -qi '</script' "$md/$mx"; then
      rm -f "$md/$mx"; log "ERROR: $mx is not MedlinePlus topic XML (removed). Re-run the installer."; exit 1
    fi
    SD="$(cd "$(dirname "$0")" && pwd)"; tpl="$md/_MedlinePlus.html"
    if [ -f "$SD/medlineplus/MedlinePlus.html" ]; then cp "$SD/medlineplus/MedlinePlus.html" "$tpl"
    else get_repo medlineplus/MedlinePlus.html "$tpl" || { log "ERROR: download failed: medlineplus/MedlinePlus.html"; exit 1; }; fi
    mark='<script type="text/xml" id="data"></script>'
    grep -qF "$mark" "$tpl" || { log "ERROR: medlineplus/MedlinePlus.html has no data marker. Re-run the installer."; exit 1; }
    awk -v mark="$mark" -v xf="$md/$mx" '{ i = index($0, mark)
      if (!i) { print; next }
      printf "%s<script type=\"text/xml\" id=\"data\">", substr($0, 1, i - 1)
      while ((getline l < xf) > 0) print l
      printf "</script>%s\n", substr($0, i + length(mark)) }' "$tpl" > "$md/MedlinePlus-Health-Topics.html"
    # The page holds all the data: drop the XML (and any older day's copy) and the template.
    rm -f "$md"/mplus_topics_* "$tpl"
    log "medlineplus: Medical/MedlinePlus/MedlinePlus-Health-Topics.html ($(( ($(wc -c < "$md/MedlinePlus-Health-Topics.html") + 524288) / 1048576 )) MB)"
  else
    log "medlineplus: NOT FOUND (no topic file listed on medlineplus.gov/xml.html)"
  fi
else
  log "=== [5e] MedlinePlus health topics not selected - add --medlineplus to include (~30 MB) ==="
fi

# ================================================================ 6. PDFs
log "=== [6/8] Public-domain manuals (PDF) ==="
ia_pdf(){ curl -sL -A "$UA" "https://archive.org/metadata/$1" | grep -oE '"name":"[^"]+\.pdf"' | sed -E 's/"name":"([^"]+)"/\1/' | grep -vE '_text\.pdf$' | head -n1; }
get_pdf(){ # id  localname  destdir   (archive.org item)
  f="$(ia_pdf "$1")"
  if [ -z "$f" ]; then log "pdf: none for $1"; return; fi
  enc="$(printf '%s' "$f" | sed 's/ /%20/g')"
  get_pdf_url "https://archive.org/download/$1/$enc" "$2" "$3"
}
get_pdf_url(){ # url  localname  destdir   (direct link)
  out="$3/$2"
  log "pdf: $2"
  fetch "$1" "$out"
  # validate it's really a PDF; drop error pages / empties
  if [ -f "$out" ]; then
    if [ "$(head -c 4 "$out" 2>/dev/null)" != "%PDF" ]; then log "  ERROR: $2 was not a valid PDF (removed)"; rm -f "$out"; exit 1; fi
  else log "  WARN: $2 failed to download"; fi
}
get_html_doc(){ # baseurl  htmlfile  localname  destdir   (an HTML page + the images/ it references)
  # Grabs the page and every images/<file> it links, so it opens fully offline in a browser.
  out="$4/$3"
  log "html: $3"
  fetch "$1/$2" "$out"
  if ! head -c 400 "$out" 2>/dev/null | grep -qi '<html\|<!doctype'; then
    log "  ERROR: $3 was not HTML (removed)"; rm -f "$out"; exit 1
  fi
  imgs="$(grep -oE 'src="images/[^"]+"' "$out" | sed -E 's/.*images\/([^"]+)".*/\1/' | sort -u)"
  [ -n "$imgs" ] && mkdir -p "$4/images"
  for im in $imgs; do fetch "$1/images/$im" "$4/images/$im"; done
}
AFM="$ROOT/Manuals/ArmyFieldManuals"; MPDF="$ROOT/Medical/Manuals-PDF"
if [ -n "$ONLY" ]; then log "pdf: manuals not touched (--only)"; else
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
get_pdf "FM2110MCRP411.1DFieldHygieneAndSanitation"          "FM 21-10 Field Hygiene and Sanitation.pdf" "$AFM"
get_pdf "armyfm5428concreteandmasonry"                       "FM 5-428 Concrete and Masonry.pdf" "$AFM"
get_pdf "TM5-295"                                            "TM 5-295 Water Supply and Water Purification.pdf" "$AFM"
# More public-domain US Army manuals (#130): navigation, engineering and cold-weather survival.
get_pdf "FM3-25x26"                                          "FM 3-25.26 Map Reading and Land Navigation.pdf" "$AFM"
get_pdf "fm-31-70-basic-cold-weather-manual-1968"           "FM 31-70 Basic Cold Weather Manual (1968).pdf" "$AFM"
get_pdf "where-there-is-no-doctor"                           "Where There Is No Doctor.pdf" "$MPDF"
get_pdf "where-there-is-no-dentist-web-full-book"            "Where There Is No Dentist.pdf" "$MPDF"
# Advanced care when help is delayed: USUHS + Henry M. Jackson Foundation, 2025, CC BY-NC-SA 4.0 (not public domain).
get_pdf_url "https://www.usuhs.edu/sites/default/files/2025-09/Layperson%27s_Guide_to_Prolonged_Casualty_Care_090825_ACC.pdf" "A Practical Guide to Prolonged Casualty Care (USUHS-HJF 2025).pdf" "$MPDF"
# WHO childbirth references (CC BY-NC-SA 3.0 IGO); citations, audience and update cautions in Medical/READ-ME-FIRST.
get_pdf_url "https://iris.who.int/server/api/core/bitstreams/3bda1306-da5d-487d-b2ad-aff995112a7a/content" "WHO Managing Complications in Pregnancy and Childbirth 2017.pdf" "$MPDF"
get_pdf_url "https://iris.who.int/server/api/core/bitstreams/12fdb499-733d-4614-aafc-88dcbbb3c829/content" "WHO Recommendations on Maternal Health 2025.pdf" "$MPDF"
# USDA Complete Guide to Home Canning (Agriculture Information Bulletin 539, revised 2015; US-government work).
# The official electronic copy is 8 PDFs from the USDA-funded National Center for Home Food Preservation.
CAN="$ROOT/Manuals/Food-Preservation/USDA-Complete-Guide-to-Home-Canning-2015"
get_pdf_url "https://nchfp.uga.edu/papers/guide/INTRO_HomeCanrev0715.pdf" "0 Introduction.pdf" "$CAN"
get_pdf_url "https://nchfp.uga.edu/papers/guide/GUIDE01_HomeCan_rev0715.pdf" "1 Principles of Home Canning.pdf" "$CAN"
get_pdf_url "https://nchfp.uga.edu/papers/guide/GUIDE02_HomeCan_rev0715.pdf" "2 Fruit and Fruit Products.pdf" "$CAN"
get_pdf_url "https://nchfp.uga.edu/papers/guide/GUIDE03_HomeCan_rev0715.pdf" "3 Tomatoes and Tomato Products.pdf" "$CAN"
get_pdf_url "https://nchfp.uga.edu/papers/guide/GUIDE04_HomeCan_rev0715.pdf" "4 Vegetables and Vegetable Products.pdf" "$CAN"
get_pdf_url "https://nchfp.uga.edu/papers/guide/GUIDE05_HomeCan_rev0715.pdf" "5 Poultry, Red Meats, and Seafoods.pdf" "$CAN"
get_pdf_url "https://nchfp.uga.edu/papers/guide/GUIDE06_HomeCan_rev0715.pdf" "6 Fermented Foods and Pickled Vegetables.pdf" "$CAN"
get_pdf_url "https://nchfp.uga.edu/papers/guide/GUIDE07_HomeCan_rev0715.pdf" "7 Jams and Jellies.pdf" "$CAN"
# Canning, Freezing, Storing Garden Produce (USDA Agriculture Information Bulletin 410; US-government work, public domain).
get_pdf "canningfreezings00unit" "USDA Canning, Freezing, Storing Garden Produce (AIB 410).pdf" "$ROOT/Manuals/Food-Preservation"
# Survival & preparedness (public domain):
SP="$ROOT/Manuals/Survival-Preparedness"
# FEMA Are You Ready? An In-Depth Guide to Citizen Preparedness (IS-22; US-government work, public domain).
get_pdf "FemaEmergencyHandbook-areYouReady" "FEMA Are You Ready - Citizen Preparedness.pdf" "$SP"
# Knots, Splices and Rope Work, A. Hyatt Verrill (1912; public domain, 150+ illustrations).
get_pdf "knotssplicesrope00verr" "Knots, Splices and Rope Work (Verrill).pdf" "$SP"
# EPA Emergency Disinfection of Drinking Water (US-government work, public domain): making water safe when the tap is unsafe.
get_pdf_url "https://www.epa.gov/sites/default/files/2017-09/documents/emergency_disinfection_of_drinking_water_sept2017.pdf" "EPA Emergency Disinfection of Drinking Water.pdf" "$SP"
# Hunting with the Bow and Arrow, Saxton Pope (1923; public domain): making and shooting bows, hunting game.
get_pdf "hunting-with-the-bow-and-arrow" "Hunting with the Bow and Arrow (Pope 1923).pdf" "$SP"
# Live off the land: fishing, trapping and outdoor living (public domain; #130).
get_pdf "bookofcampingwoo01keph"                     "The Book of Camping and Woodcraft (Kephart 1910).pdf" "$SP"
get_pdf "deadfalls-and-snares-by-a.-r.-harding-1907" "Deadfalls and Snares (Harding 1907).pdf" "$SP"
get_pdf "baitanglingforco00rhearich"                 "Bait Angling for Common Fishes (Rhead 1907).pdf" "$SP"
# Household do-it-yourself from common materials (public domain):
DIY="$ROOT/Manuals/Household-DIY"
# The Boy Mechanic, Volume 1: 700 Things for Boys to Do (1913; public domain). Dated; some projects are unsafe by modern standards -- see Manuals/READ-ME-FIRST.
get_pdf "boymechanicthing01unse" "The Boy Mechanic Vol 1 - 700 Things to Do (1913).pdf" "$DIY"
# Metalworking trades (public domain; #130): welding, forging and machine-shop work for repairing
# and making metal parts and tools. Core skills are timeless; use modern safety gear and ventilation.
MW="$ROOT/Manuals/Metalworking"
get_pdf "TM9-237"                    "TM 9-237 Welding Theory and Application.pdf" "$MW"
get_pdf "practicalblacksm00rich"     "Practical Blacksmithing (1888).pdf" "$MW"
get_pdf "textbookofelemen00smitrich" "Elements of Machine Work (1910).pdf" "$MW"
# Natural-medicine historical references (public domain; historical, NOT current medical advice -- see Medical/READ-ME-FIRST):
NAT="$ROOT/Medical/Natural-Medicine"
# King's American Dispensatory (Felter & Lloyd; public domain): the major eclectic materia medica of medicinal plants.
get_pdf "kingsamericandis01kinguoft" "Kings American Dispensatory Vol 1.pdf" "$NAT"
get_pdf "kingsamericandis02kinguoft" "Kings American Dispensatory Vol 2.pdf" "$NAT"
# Culpeper's Complete Herbal (public domain): classic English herbal. Historical reference only; do not attempt the remedies.
get_pdf "53357467.6000.emory.edu" "Culpepers Complete Herbal.pdf" "$NAT"
# Food growing & raising animals (public-domain classics; #130). Core skills are timeless; some
# pest/disease/chemical advice is dated — read as background, not current pesticide guidance.
FG="$ROOT/Manuals/Food-Growing"
# Pin the exact .pdf by direct link: these two items also carry a larger _bw.pdf, which the
# PowerShell installer (largest file) would otherwise pick, differing from bash (#184 review).
get_pdf_url "https://archive.org/download/productiveveget00lloy/productiveveget00lloy.pdf" "Productive Vegetable Growing (Lloyd 1918).pdf" "$FG"
get_pdf "productivepoult02lewigoog"  "Productive Poultry Husbandry (Lewis 1913).pdf" "$FG"
get_pdf_url "https://archive.org/download/cu31924003227729/cu31924003227729.pdf" "Langstroth on the Hive and the Honey-Bee (1904).pdf" "$FG"
# Emergency Childbirth (US Office of Civil Defense + Public Health Service; US-government work, public domain).
# Project Gutenberg #26923 e-text (HTML + figures), header kept. Emergency-delivery reference for when help is delayed.
EC="$ROOT/Medical/Emergency-Childbirth"
get_html_doc "https://www.gutenberg.org/cache/epub/26923" "pg26923-images.html" "Emergency Childbirth (US Civil Defense).html" "$EC"
fi

# ================================================================ 7. Wikipedia + Maps
if [ "$SKIP_WIKI" = 0 ]; then
  log "=== [7/8] Wikipedia (full, no images - Kiwix ZIM, ~49 GB) ==="
  mkdir -p "$ROOT/Wikipedia"
  wk="$(latest_zim 'https://download.kiwix.org/zim/wikipedia/' 'wikipedia_en_all_nopic_')"
  if [ -n "$wk" ]; then log "zim: $wk"; fetch "https://download.kiwix.org/zim/wikipedia/$wk" "$ROOT/Wikipedia/$wk"
  else log "Wikipedia: ZIM not found"; fi
else log "=== [7/8] Wikipedia SKIPPED ==="; fi

if [ "$SKIP_MAPS" = 0 ]; then
  log "=== [8/8] Offline maps (OsmAnd) - region: $REGION ==="
  # grep -c prints 0 AND exits 1 on no match: '|| echo 0' made it "0 0" (#192)
  n=$(grep -c . "$ROOT/OsmAnd/_filelist.txt" 2>/dev/null || true)
  if [ "${n:-0}" = "0" ]; then
    log "osmand: no maps matched region '$REGION'. Run with --list-regions to see valid names. Skipping maps."
  else
  log "osmand: $n map files for '$REGION'"
  # OsmAnd republishes maps under the same name: the index's containerSize (bytes) tells
  # a current copy from an older edition (#57).
  while IFS= read -r fn; do
    [ -n "$fn" ] || continue
    cs="$(grep -oE "<region [^>]*name=\"$fn\"[^>]*>" "$ROOT/OsmAnd/_index.xml" | head -n1 | grep -oE 'containerSize="[0-9]+"' | grep -oE '[0-9]+')"
    fetch_sized "https://download.osmand.net/download.php?standard=yes&file=$fn" "$ROOT/OsmAnd/$fn" "$cs"
  done < "$ROOT/OsmAnd/_filelist.txt"
  fi
  # OffRoad draws the maps at every zoom level and asks for this world map on first start.
  # It is small, region-independent, and also usable by the Android app.
  world="World_basemap_mini_2.obf.zip"
  world_cs="$(grep -oE "<region [^>]*name=\"$world\"[^>]*>" "$ROOT/OsmAnd/_index.xml" | head -n1 | grep -oE 'containerSize="[0-9]+"' | grep -oE '[0-9]+')"
  if [ "$BM_ONLY" = 0 ] && [ ! -f "$ROOT/OsmAnd/$world" ] && [ -n "$world_cs" ]; then
    log "osmand: $world (world basemap for the desktop viewer)"
    ( fetch_sized "https://download.osmand.net/download.php?standard=yes&file=$world" "$ROOT/OsmAnd/$world" "$world_cs" soft ) || true
  elif [ "$BM_ONLY" = 0 ] && [ ! -f "$ROOT/OsmAnd/$world" ]; then
    log "osmand note: $world is not in the current index; skipping the optional basemap."
  fi

  # desktop map viewer (OsmAndMapCreator + portable Java) — use maps on a PC, no phone
  log "=== [8b] Desktop map viewers (OffRoad + OsmAndMapCreator + portable Java) ==="
  MVD="$ROOT/OsmAnd/MapViewer-Desktop"; mkdir -p "$MVD/app"
  if [ "$HAVE_UNZIP" = 1 ]; then
    # "latest" URLs keep their file name across new editions: fetch by remote size (#57)
    mcu="https://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip"
    if fetch_sized "$mcu" "$MVD/OsmAndMapCreator.zip" "$(remote_size "$mcu")" soft; then
      # unpack to a new folder; replace the working viewer only if the unpack worked
      rm -rf "$MVD/app.new"
      if unzip -o -q "$MVD/OsmAndMapCreator.zip" -d "$MVD/app.new" && [ -f "$MVD/app.new/OsmAndMapCreator.sh" ]; then
        rm -rf "$MVD/app"; mv "$MVD/app.new" "$MVD/app"
      else
        rm -rf "$MVD/app.new"; log "  mapviewer ERROR: could not unpack OsmAndMapCreator.zip (old viewer kept). Delete it and re-run."
      fi
    fi
    jreurl="https://api.adoptium.net/v3/binary/latest/21/ga/${PLAT}/${JARCH}/jre/hotspot/normal/eclipse"
    [ "$PLAT" = mac ] && jreurl="https://api.adoptium.net/v3/binary/latest/21/ga/mac/${JARCH}/jre/hotspot/normal/eclipse"
    if fetch_sized "$jreurl" "$MVD/jre.tar.gz" "$(remote_size "$jreurl")" soft; then
      rm -rf "$MVD/_jre"; mkdir -p "$MVD/_jre"; tar -xf "$MVD/jre.tar.gz" -C "$MVD/_jre" 2>/dev/null
      if [ -n "$(find "$MVD/_jre" -name java -type f 2>/dev/null | head -n1)" ]; then
        rm -rf "$MVD/jre"; mv "$MVD/_jre"/*/ "$MVD/jre" 2>/dev/null
      else log "  mapviewer ERROR: could not unpack jre.tar.gz (old Java kept). Delete it and re-run."; fi
      rm -rf "$MVD/_jre"
    fi
    # OffRoad is a cross-platform OsmAnd-format viewer: it renders the .obf files locally
    # on Windows and macOS too, which the bundled OsmAndMapCreator cannot (#107).
    log "mapviewer: OffRoad 0.6-beta2"
    oru="https://master.dl.sourceforge.net/project/offroadosm/OffRoad_Unstable/0.6-beta2/OffRoad-bin-0.6-beta2.zip"
    if ( fetch_sized "$oru" "$MVD/OffRoad.zip" 41634058 soft ); then
      rm -rf "$MVD/offroad.new"
      if unzip -o -q "$MVD/OffRoad.zip" -d "$MVD/offroad.new" && [ -f "$MVD/offroad.new/OffRoad.jar" ]; then
        # OffRoad 0.6-beta2's SQLite has no Mac/aarch64 native. Keep the manifest's
        # original jar name while replacing it with the ARM64-compatible xerial build.
        if [ "$PLAT" = mac ] && [ "$JARCH" = aarch64 ]; then
          sqlu="https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.46.1.3/sqlite-jdbc-3.46.1.3.jar"
          if ( fetch_sized "$sqlu" "$MVD/sqlite-jdbc-3.46.1.3.jar" 14127503 soft ) && [ -f "$MVD/offroad.new/lib/sqlite-jdbc-3.30.1.jar" ]; then
            mv -f "$MVD/sqlite-jdbc-3.46.1.3.jar" "$MVD/offroad.new/lib/sqlite-jdbc-3.30.1.jar"
          else
            rm -rf "$MVD/offroad.new"
            log "  mapviewer ERROR: Apple Silicon needs sqlite-jdbc 3.46.1.3; old OffRoad kept. Re-run to retry."
          fi
        fi
        if [ -f "$MVD/offroad.new/OffRoad.jar" ]; then
          rm -rf "$MVD/offroad"; mv "$MVD/offroad.new" "$MVD/offroad"
        fi
      else
        rm -rf "$MVD/offroad.new"; log "  mapviewer ERROR: could not unpack OffRoad.zip (old viewer kept). Delete it and re-run."
      fi
    fi
    # Shared map preparation: unzip the .obf.zip files into <OsmAnd>/obf. Staged, so a
    # damaged replacement must not destroy the previous map.
    cat > "$MVD/prepare-maps.sh" <<'EOS'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
MAPS="$(cd "$DIR/.." && pwd)"; OBF="$MAPS/obf"; mkdir -p "$OBF"
echo "Preparing maps for desktop viewing (first run can take several minutes)..."
for z in "$MAPS"/*.obf.zip; do
  [ -e "$z" ] || continue
  base="$(basename "$z" .zip)"
  stamp="$OBF/$base.cksum"
  fingerprint="$(cksum < "$z")" || exit 1
  if [ -f "$OBF/$base" ] && [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$fingerprint" ]; then continue; fi
  # Stage first: a damaged replacement must not destroy the previous map.
  stage="$(mktemp -d "$OBF/.prepare-XXXXXX")" || exit 1
  trap 'rm -rf "$stage"' EXIT
  if ! unzip -o -q "$z" -d "$stage" || [ ! -f "$stage/$base" ]; then
    echo "ERROR: could not unpack $z (previous map kept)." >&2
    exit 1
  fi
  mv -f "$stage/$base" "$OBF/$base" || exit 1
  printf '%s\n' "$fingerprint" > "$stamp" || exit 1
  rm -rf "$stage"
  trap - EXIT
done
echo "Maps ready in: $OBF"
EOS
    cat > "$MVD/VIEW-MAPS-OFFLINE.sh" <<'EOS'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
JAVA="$(find "$DIR/jre" -name java -type f 2>/dev/null | head -n1)"
[ -n "$JAVA" ] || JAVA=java
bash "$DIR/prepare-maps.sh" || exit 1
OFFROAD_HOME="$DIR/offroad-home"
MAP_LINK="$OFFROAD_HOME/.OffRoad/maps"
mkdir -p "$OFFROAD_HOME/.OffRoad" || exit 1
# OffRoad logs a scary first-run panic when its own settings file is absent.
: >> "$OFFROAD_HOME/.OffRoad/offroad.properties" || exit 1
# A link keeps the second copy of the maps at zero bytes. Remove a stale link only.
if [ -L "$MAP_LINK" ] && [ ! -e "$MAP_LINK" ]; then rm -f "$MAP_LINK"; fi
if [ ! -e "$MAP_LINK" ]; then
  ln -s "$DIR/../obf" "$MAP_LINK" || { echo "ERROR: could not link the map folder at $MAP_LINK" >&2; exit 1; }
fi
[ -f "$DIR/offroad/OffRoad.jar" ] || { echo "ERROR: OffRoad viewer is missing. Re-run the installer." >&2; exit 1; }
echo "Launching the OffRoad map viewer (fully offline)..."
exec "$JAVA" "-Duser.home=$OFFROAD_HOME" "-Dcom.sun.xml.bind.v2.bytecode.ClassTailor.noOptimize=true" -jar "$DIR/offroad/OffRoad.jar"
EOS
    cat > "$MVD/VIEW-MAPS-ON-PC.sh" <<'EOS'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
# find bundled java
JAVA="$(find "$DIR/jre" -name java -type f 2>/dev/null | head -n1)"
[ -n "$JAVA" ] && export PATH="$(dirname "$JAVA"):$PATH"
bash "$DIR/prepare-maps.sh" || exit 1
echo "If the map area stays BLANK: on macOS this viewer draws online map tiles, not the"
echo "drive's maps, so it is blank with no internet (issue 15; Linux may work offline, untested)."
echo "For offline maps on Windows, macOS or Linux, use VIEW-MAPS-OFFLINE instead."
# one launch only (bash runs both sh and bash scripts); the old "sh || bash" started a 2nd viewer when the 1st exited non-zero
bash "$DIR/app/OsmAndMapCreator.sh"
EOS
    chmod +x "$MVD/prepare-maps.sh" "$MVD/VIEW-MAPS-OFFLINE.sh" "$MVD/VIEW-MAPS-ON-PC.sh" 2>/dev/null
    find "$MVD/app" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
    find "$MVD/jre" -name java -exec chmod +x {} \; 2>/dev/null
  else
    log "desktop map viewer: skipped (install 'unzip' then re-run to enable)"
  fi
else log "=== [8/8] Maps SKIPPED ==="; fi

# ================================================================ 8c. Browser maps (opt-in)
# Street maps in any web browser on Windows, macOS and Linux - no app, no Java. Protomaps
# state maps made by Project NOMAD (MIT; map data (c) OpenStreetMap contributors, ODbL),
# NOMAD's style/fonts/symbols, the MapLibre GL JS viewer (BSD-3) and Caddy (Apache-2.0) as a
# local web server. NOMAD has US states only; any region also gets a low-detail world map.
if { [ "$SKIP_MAPS" = 0 ] || [ "$BM_ONLY" = 1 ]; } && [ "$BROWSER_MAPS" = 1 ]; then
  log "=== [8c] Browser maps (Project NOMAD / Protomaps + MapLibre + Caddy) ==="
  MB="$ROOT/Maps-Browser"; mkdir -p "$MB/pmtiles" "$MB/viewer/lib" "$MB/server"
  NM="https://github.com/Crosstalk-Solutions/project-nomad-maps/raw/refs/heads/master"
  # which states: US / world / northamerica = all; Us_<state>[_<area>] = that state.
  # (functions, not inline: bash 3.2 on macOS misreads "case" inside $( ... ))
  nomad_want(){ printf '%s\n' "$REGION" | tr ',;' '  ' | tr ' ' '\n' | while IFS= read -r tok; do   # \n: read skips a last line without one
    [ -z "$tok" ] && continue
    t="$(alias_region "$tok" | tr 'A-Z' 'a-z')"
    case "$t" in us|world|northamerica) echo ALL ;; us_*) printf '%s\n' "${t#us_}" | tr '-' '_' ;; esac
  done; }
  nomad_keep(){ # map-name  wanted... -> exit 0 if the map is wanted
    r="$1"; shift
    case "$r" in global*) return 0 ;; esac
    for w in "$@"; do case "$w" in ALL|"$r"|"$r"_*) return 0 ;; esac; done
    return 1
  }
  want="$(nomad_want)"
  names="$(curl -sL -H "User-Agent: oel" "https://api.github.com/repos/Crosstalk-Solutions/project-nomad-maps/contents/pmtiles" \
    | grep -oE '"name"[ ]*:[ ]*"[a-z_-]+_[0-9]{4}-[0-9]{2}\.pmtiles"' | sed -E 's/.*"([^"]+)"$/\1/' | LC_ALL=C sort)"
  # newest file per map (names end _YYYY-MM.pmtiles); the world map first so states draw over it
  list="$(printf '%s\n' "$names" | sed -E 's/_[0-9]{4}-[0-9]{2}\.pmtiles$//' | sort -u | while IFS= read -r r; do
    [ -n "$r" ] && nomad_keep "$r" $want && printf '%s\n' "$names" | grep -E "^${r}_[0-9]{4}-[0-9]{2}\.pmtiles$" | tail -n1
  done | awk '/^global/{print; next} {rest=rest $0 "\n"} END{printf "%s", rest}')"
  ns="$(printf '%s\n' "$list" | grep -c -v -e '^global' -e '^$')"
  [ "$ns" = 0 ] && log "browser maps: no US state in region '$REGION' (these maps cover the US) - adding the world map only"
  log "browser maps: $(printf '%s\n' "$list" | grep -c .) map files ($ns US states)"
  : > "$MB/_ok.txt"
  printf '%s\n' "$list" | while IFS= read -r fn; do
    [ -z "$fn" ] && continue
    log "map: $fn"; fetch "$NM/pmtiles/$fn" "$MB/pmtiles/$fn"
    # no published fingerprints: check the PMTiles header (the file starts with "PMTiles")
    if [ "$(head -c 7 "$MB/pmtiles/$fn" 2>/dev/null)" = "PMTiles" ]; then echo "$fn" >> "$MB/_ok.txt"
    else log "  WARN: $fn is not a PMTiles file (removed) - run again"; rm -f "$MB/pmtiles/$fn"; fi
  done
  if [ -s "$MB/_ok.txt" ]; then printf '[%s]\n' "$(sed 's/.*/"&"/' "$MB/_ok.txt" | paste -sd, -)" > "$MB/regions.json"; fi
  rm -f "$MB/_ok.txt"
  # map style, fonts and symbols (one archive, no symlinks inside)
  fetch_sized "$NM/base-assets.tar.gz" "$MB/base-assets.tar.gz" "$(remote_size "$NM/base-assets.tar.gz")"   # same name on every update (#57)
  rm -rf "$MB/assets-new"; mkdir -p "$MB/assets-new"
  if tar -xzf "$MB/base-assets.tar.gz" -C "$MB/assets-new" 2>/dev/null && [ -f "$MB/assets-new/tozip/nomad-base-styles.json" ]; then
    rm -rf "$MB/assets"; mv "$MB/assets-new/tozip" "$MB/assets"
  else log "  WARN: could not unpack the map style and fonts (base-assets.tar.gz)"; fi
  rm -rf "$MB/assets-new"
  # map viewer libraries (pinned versions)
  for u in maplibre-gl@4.7.1/dist/maplibre-gl.js maplibre-gl@4.7.1/dist/maplibre-gl.css pmtiles@4.4.0/dist/pmtiles.js; do
    f="$MB/viewer/lib/$(basename "$u")"; fetch "https://unpkg.com/$u" "$f"
    grep -q -i -E 'maplibregl|pmtiles' "$f" 2>/dev/null || { log "  WARN: $(basename "$u") did not download (removed)"; rm -f "$f"; }
  done
  # Caddy web server for every platform (one release); folder = <os>-<arch>
  crel="$(curl -sL -H "User-Agent: oel" "https://api.github.com/repos/caddyserver/caddy/releases/latest")"
  for ck in windows_amd64.zip windows_arm64.zip mac_arm64.tar.gz mac_amd64.tar.gz linux_amd64.tar.gz linux_arm64.tar.gz; do
    cu="$(printf '%s' "$crel" | grep -oE '"browser_download_url"[ ]*:[ ]*"[^"]+_'"$ck"'"' | sed -E 's/.*"(https[^"]+)"$/\1/' | head -n1)"
    [ -z "$cu" ] && { log "  WARN: caddy $ck not in the latest Caddy release"; continue; }
    cd_="${ck%.zip}"; cd_="${cd_%.tar.gz}"; cd_="$(printf '%s' "$cd_" | tr '_' '-')"
    log "caddy: $(basename "$cu")"; fetch "$cu" "$MB/server/$(basename "$cu")"
    rm -rf "$MB/server/$cd_"; mkdir -p "$MB/server/$cd_"   # keeps Caddy's LICENSE (Apache-2.0)
    case "$ck" in
      *.zip)    if [ "$HAVE_UNZIP" = 1 ]; then unzip -o -q "$MB/server/$(basename "$cu")" -d "$MB/server/$cd_"; else log "  $ck: install 'unzip' to unpack it"; fi ;;
      *.tar.gz) tar -xzf "$MB/server/$(basename "$cu")" -C "$MB/server/$cd_" || log "  WARN: could not unpack $ck" ;;
    esac
  done
  # viewer page + OPEN-MAPS launchers: from the repo (local clone, else GitHub). The .bat gets
  # Windows line ends and the .sh Unix line ends, whatever the source had.
  SD="$(cd "$(dirname "$0")" && pwd)"
  for f in index.html OPEN-MAPS.sh OPEN-MAPS.bat; do
    if [ -f "$SD/maps-viewer/$f" ]; then cp "$SD/maps-viewer/$f" "$MB/_$f"
    else get_repo "maps-viewer/$f" "$MB/_$f" || { rm -f "$MB/_$f"; log "ERROR: download failed: maps-viewer/$f. Re-run the installer."; exit 1; }; fi
  done
  mv -f "$MB/_index.html" "$MB/viewer/index.html"
  tr -d '\r' < "$MB/_OPEN-MAPS.sh" > "$MB/OPEN-MAPS.sh"; chmod +x "$MB/OPEN-MAPS.sh" 2>/dev/null
  tr -d '\r' < "$MB/_OPEN-MAPS.bat" | sed 's/$/\r/' > "$MB/OPEN-MAPS.bat"
  rm -f "$MB/_OPEN-MAPS.sh" "$MB/_OPEN-MAPS.bat"
  log "browser maps: run Maps-Browser/OPEN-MAPS (.bat on Windows, .sh on macOS/Linux)"
else
  log "=== [8c] Browser maps not selected - add --browser-maps to include (~16.5 GB for the US) ==="
fi

# ================================================================ phone apps
log "=== Phone apps (port the library to a phone) ==="
PA="$ROOT/Phone-Apps"
if [ -n "$ONLY" ]; then log "phone apps: not touched (--only)"; else
ku="$(gh_asset_latest kiwix/kiwix-android 'universal-standalone\.apk$')"
[ -z "$ku" ] && ku="$(gh_asset_latest kiwix/kiwix-android '\.apk$')"
[ -n "$ku" ] && { log "phone app: Kiwix $(basename "$ku")"; fetch "$ku" "$PA/$(basename "$ku")"; }
fi
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
export LD_LIBRARY_PATH="$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" DYLD_LIBRARY_PATH="$LIBDIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
echo "__NOTE__"
echo "The AI is a helper for finding and summarizing info - for anything safety-critical, follow the bundled manuals."
exec "$BIN" -m "$DIR/models/__MODEL__" __ARGS__
EOS
sed -i.bak -e "s|__TOOL__|$2|" -e "s|__MODEL__|$3|" -e "s|__GPU__|$4|" -e "s|__ARGS__|$5|" -e "s|__NOTE__|$6|" "$AO/$1" && rm -f "$AO/$1.bak"
chmod +x "$AO/$1" 2>/dev/null
}
if [ -z "${ONLY:-}" ]; then   # --only writes just the launchers of the piece it adds (#74)
make_sh "chat-3B-light.sh"   llama-cli    "Llama-3.2-3B-Instruct-Q4_K_M.gguf"      0 "-c 4096" "Offline AI - Llama 3.2 3B (light). Ctrl+C to quit."
if [ "$LITE" = 0 ] && [ "$SKIP_MODELS" = 0 ]; then
make_sh "chat-8B-smart.sh"   llama-cli    "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" 0 "-c 4096" "Offline AI - Llama 3.1 8B (smart). Ctrl+C to quit."
make_sh "chat-GPU-Qwen7B.sh" llama-cli    "Qwen2.5-7B-Instruct-Q4_K_M.gguf"        1 "-c 4096 -ngl 99" "Offline AI - Qwen2.5 7B on the GPU (Metal on a Mac, Vulkan on Linux)."
fi
make_sh "web-ui.sh"          llama-server "Llama-3.2-3B-Instruct-Q4_K_M.gguf"      0 "-c 4096 --host 127.0.0.1 --port 8080" "Open http://127.0.0.1:8080 when it says 'server is listening'."
fi
# .bat launchers: same text as Get-OfflineLibrary.ps1 writes, with Windows (CRLF) line ends.
make_bat(){ # file  title  exe  model  args  [note]
  { echo "@echo off"; echo "title $2"; echo 'cd /d "%~dp0"'
    [ -n "$6" ] && printf '%s\n' "$6"
    echo 'echo The AI is a helper for finding and summarizing info - for anything safety-critical, follow the bundled manuals.'
    echo "\"%~dp0$3\" -m \"%~dp0models\\$4\" $5"; echo "pause"; } | sed 's/$/\r/' > "$AO/$1"
}
if [ -z "${ONLY:-}" ]; then
make_bat "CHAT-3B-light.bat"   "Offline AI - Llama 3.2 3B (light)" 'engine\x64\llama-cli.exe' "Llama-3.2-3B-Instruct-Q4_K_M.gguf" "-c 4096"
if [ "$LITE" = 0 ] && [ "$SKIP_MODELS" = 0 ]; then
make_bat "CHAT-8B-smart.bat"   "Offline AI - Llama 3.1 8B (smart)" 'engine\x64\llama-cli.exe' "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" "-c 4096"
make_bat "CHAT-GPU-Qwen7B.bat" "Offline AI - Qwen2.5 7B (GPU)"     'engine\vulkan-x64\llama-cli.exe' "Qwen2.5-7B-Instruct-Q4_K_M.gguf" "-c 4096 -ngl 99" 'echo If this errors with out-of-memory, your GPU is too small - change -ngl 99 to a lower
echo number (e.g. -ngl 20) or use a CPU launcher instead.'
fi
make_bat "WEB-UI.bat"          "Offline AI - Web UI"               'engine\x64\llama-server.exe' "Llama-3.2-3B-Instruct-Q4_K_M.gguf" "-c 4096 --host 127.0.0.1 --port 8080" 'echo When it says "server listening", open a browser to http://127.0.0.1:8080'
fi
if [ "$TRANSLATE" = 1 ]; then
# Same text as Get-OfflineLibrary.ps1. No batch special characters, and no | & or \ (sed) in the prompt or notes.
TR_PROMPT='You are an interpreter between two people. Their first message names two languages: reply only with Ready. After that, for every message: if it is written in the first language, translate it into the second language; if it is written in the second language, translate it into the first language. Never repeat a message in the language it was written in. Write only the translation, with no notes. Keep names, numbers, doses and times exactly as written.'
TR_ARGS="-c 4096 --temp 0.2 -sys \"$TR_PROMPT\""
make_bat "TRANSLATE.bat" "Offline translator - Qwen3 4B" 'engine\x64\llama-cli.exe' "$TR_MODEL" "$TR_ARGS" 'echo Offline translator. First type the two languages, for example: English and Spanish. Then type what to translate.
echo Check anything about medicine, doses or safety by translating it back. Use short, simple sentences.'
make_sh "translate.sh" llama-cli "$TR_MODEL" 0 "$TR_ARGS" "Offline translator. First type the two languages, for example: English and Spanish. Check anything about medicine, doses or safety by translating it back. Ctrl+C to quit."
# Flat UI defaults, verified against llama.cpp b12110 settings-keys.constants.ts.
# The prompt contains no JSON escapes. Keep it shared with the tested CLI.
printf '{"systemMessage":"%s","temperature":0.2,"useHuggingFaceHub":false,"enableDiscoverModels":false}\n' "$TR_PROMPT" > "$AO/translate-webui.json"
cat > "$AO/translate-browser.sh" <<'EOS'
#!/usr/bin/env bash
# Offline translator in llama.cpp's bundled browser UI.
DIR="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) P=macos-arm64 ;;
  Darwin-*) P=macos-x64 ;;
  Linux-aarch64|Linux-arm64) P=linux-arm64 ;;
  *) P=linux-x64 ;;
esac
BIN="$(find "$DIR/engine/$P" -name llama-server -type f 2>/dev/null | head -n1)"
[ -n "$BIN" ] || { echo "Translator server missing: $DIR/engine/$P. Re-run the installer."; exit 1; }
[ -s "$DIR/models/__MODEL__" ] || { echo "Translator model missing. Re-run the installer with --translate."; exit 1; }
[ -s "$DIR/translate-webui.json" ] || { echo "Missing translate-webui.json. Re-run the installer with --translate."; exit 1; }
command -v curl >/dev/null || { echo "The browser translator needs curl. Install curl or use translate.sh."; exit 1; }
case "$P" in macos-*) OPENER=open ;; *) OPENER=xdg-open ;; esac
command -v "$OPENER" >/dev/null || { echo "The browser translator needs $OPENER and a desktop browser. Use translate.sh instead."; exit 1; }
chmod +x "$BIN" 2>/dev/null
LIBDIR="$(dirname "$BIN")"
export LD_LIBRARY_PATH="$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" DYLD_LIBRARY_PATH="$LIBDIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
LOG="$(mktemp "${TMPDIR:-/tmp}/oel-translator.XXXXXX")" || exit 1
PID=
cleanup(){
  if [ -n "$PID" ]; then kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; fi
  rm -f "$LOG"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
URL=http://127.0.0.1:8087
ALIAS="oel-translator-$$-$(date +%s)"
echo "Starting offline translator (up to 120 seconds). Ctrl+C stops the server."
"$BIN" -m "$DIR/models/__MODEL__" -c 4096 -ngl 0 --temp 0.2 --offline --host 127.0.0.1 --port 8087 --alias "$ALIAS" --webui-config-file "$DIR/translate-webui.json" >"$LOG" 2>&1 &
PID=$!
READY=0
SECONDS=0
for ((attempt=0; attempt<120 && SECONDS<120; attempt++)); do
  kill -0 "$PID" 2>/dev/null || break
  # A response from an occupied port must never open an unrelated service.
  if curl --noproxy '*' -fsS --max-time 1 "$URL/v1/models" 2>/dev/null | grep -qE '"id"[[:space:]]*:[[:space:]]*"'"$ALIAS"'"'; then
    kill -0 "$PID" 2>/dev/null && READY=1
    break
  fi
  sleep 1
done
if [ "$READY" != 1 ]; then
  cat "$LOG"
  if kill -0 "$PID" 2>/dev/null; then
    echo "Translator did not start within 120 seconds. Check port 8087, available RAM and the engine version (b12110 or compatible)."
  else
    wait "$PID" 2>/dev/null; SRC=$?; PID=
    echo "The translator server stopped right after it started (exit code $SRC). The log is above. If it says it could not bind, another program is using port 8087."
  fi
  exit 1
fi
echo "Opening $URL. First send the two languages, for example: English and Spanish."
echo "Use a private browser window for sensitive conversations. Closing the tab does not stop the server."
"$OPENER" "$URL" >/dev/null 2>&1 || echo "Could not open the browser. Open $URL manually."
wait "$PID"; RC=$?
PID=
[ "$RC" = 0 ] || cat "$LOG"
exit "$RC"
EOS
sed -i.bak "s|__MODEL__|$TR_MODEL|g" "$AO/translate-browser.sh" && rm -f "$AO/translate-browser.sh.bak"
chmod +x "$AO/translate-browser.sh" 2>/dev/null
cat > "$AO/translate-browser.command" <<'EOS'
#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
bash ./translate-browser.sh
RC=$?
read -r -p "Press Return to close this window. "
exit "$RC"
EOS
chmod +x "$AO/translate-browser.command" 2>/dev/null
cat <<'EOS' | sed 's/$/\r/' > "$AO/TRANSLATE-BROWSER.bat"
@echo off
title Offline translator - browser
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0translate-browser.ps1"
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%
EOS
cat <<'EOS' | sed "s|__MODEL__|$TR_MODEL|g; s/$/\r/" > "$AO/translate-browser.ps1"
# Offline translator in llama.cpp's bundled browser UI. Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$server = $null
$logs = @()
try {
  $arch = if($env:PROCESSOR_ARCHITEW6432){ $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
  $p = if($arch -eq 'ARM64'){ 'arm64' } else { 'x64' }
  $bin = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot "engine\$p") -Filter llama-server.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if(-not $bin){ throw "Translator server missing: engine\$p. Re-run the installer." }
  $model = Join-Path $PSScriptRoot 'models\__MODEL__'
  $config = Join-Path $PSScriptRoot 'translate-webui.json'
  if(-not (Test-Path -LiteralPath $model -PathType Leaf)){ throw 'Translator model missing. Re-run the installer with -Translate.' }
  if(-not (Test-Path -LiteralPath $config -PathType Leaf)){ throw 'Missing translate-webui.json. Re-run the installer with -Translate.' }
  $id = 'oel-translator-' + [guid]::NewGuid().ToString('N')
  $logs = @((Join-Path ([IO.Path]::GetTempPath()) "$id.out"), (Join-Path ([IO.Path]::GetTempPath()) "$id.err"))
  $url = 'http://127.0.0.1:8087'
  Write-Host 'Starting offline translator (up to 120 seconds). Ctrl+C stops the server.'
  $argv = "-m `"$model`" -c 4096 -ngl 0 --temp 0.2 --offline --host 127.0.0.1 --port 8087 --alias $id --webui-config-file `"$config`""
  $server = Start-Process -FilePath $bin.FullName -ArgumentList $argv -WorkingDirectory $bin.DirectoryName -NoNewWindow -PassThru -RedirectStandardOutput $logs[0] -RedirectStandardError $logs[1]
  $timer = [Diagnostics.Stopwatch]::StartNew()
  $ready = $false
  for($attempt = 0; $attempt -lt 120 -and $timer.Elapsed.TotalSeconds -lt 120; $attempt++){
    if($server.HasExited){ break }
    try {
      $request = [Net.HttpWebRequest]::Create("$url/v1/models")
      $request.Proxy = $null
      $request.Timeout = 1000
      $request.ReadWriteTimeout = 1000
      $response = $request.GetResponse()
      try {
        $reader = New-Object IO.StreamReader($response.GetResponseStream())
        try { $models = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        if($models.data.id -contains $id -and -not $server.HasExited){ $ready = $true; break }
      } finally { $response.Dispose() }
    } catch [Net.WebException] {
      if($_.Exception.Response){ $_.Exception.Response.Dispose() }
    }
    Start-Sleep -Milliseconds 1000
  }
  if(-not $ready){
    if($server.HasExited){ throw "The translator server stopped right after it started (exit code $($server.ExitCode)). The log is below. If it says it could not bind, another program is using port 8087. On Windows, security software or Smart App Control can block llama-server.exe or its DLLs." }
    throw 'Translator did not start within 120 seconds. Check port 8087, available RAM and the engine version (b12110 or compatible).'
  }
  Write-Host "Opening $url. First send the two languages, for example: English and Spanish."
  Write-Host 'Use a private browser window for sensitive conversations. Closing the tab does not stop the server.'
  try { Start-Process $url } catch { Write-Host "Could not open the browser. Open $url manually." }
  [void](Read-Host 'Press Enter here to stop the translator')
} catch {
  Write-Host $_.Exception.Message
  foreach($log in $logs){ if(Test-Path -LiteralPath $log){ Get-Content -LiteralPath $log -Tail 30 } }
  exit 1
} finally {
  if($server -and -not $server.HasExited){ Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue; $server.WaitForExit() }
  foreach($log in $logs){ Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue }
}
EOS
fi

# ================================================================ documentation
log "=== Documentation (Markdown + HTML) ==="
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
place_doc(){ # base  destpath
  for ext in md html; do
    if [ -f "$SCRIPTDIR/docs/$1.$ext" ]; then cp "$SCRIPTDIR/docs/$1.$ext" "$2.$ext"
    else
      get_repo "docs/$1.$ext" "$2.$ext" || {
        log "ERROR: documentation download failed: $1.$ext"; exit 1;
      }
    fi
  done
}
if [ -n "$ONLY" ]; then
  log "docs: already on the drive (not placed again by --only)"
  # --only writes just the piece it adds, including that piece's own guide (#152).
  case " $ONLY " in *" translate "*) place_doc "HOW-TO-TRANSLATE" "$ROOT/AI-Offline/HOW-TO-TRANSLATE"; log "docs: refreshed HOW-TO-TRANSLATE for --only translate" ;; esac
else
place_doc "START-HERE"            "$ROOT/START-HERE"
place_doc "I-NEED-TO"             "$ROOT/I-NEED-TO"
place_doc "EMERGENCY-ESSENTIALS"  "$ROOT/EMERGENCY-ESSENTIALS"
place_doc "POWER-AND-DEVICES"     "$ROOT/POWER-AND-DEVICES"
place_doc "HOW-TO-RUN-OFFLINE-AI" "$ROOT/AI-Offline/HOW-TO-RUN-OFFLINE-AI"
place_doc "HOW-TO-ASK-YOUR-DOCS"  "$ROOT/AI-Offline/DocReader-GPT4All/HOW-TO-ASK-YOUR-DOCS"
place_doc "HOW-TO-TRANSLATE"      "$ROOT/AI-Offline/HOW-TO-TRANSLATE"
place_doc "HOW-TO-USE-KIWIX"      "$ROOT/Kiwix-Reader/HOW-TO-USE-KIWIX"
place_doc "Manuals-READ-ME-FIRST" "$ROOT/Manuals/READ-ME-FIRST"
place_doc "Medical-READ-ME-FIRST" "$ROOT/Medical/READ-ME-FIRST"
place_doc "PSYCHOLOGICAL-FIRST-AID" "$ROOT/Medical/PSYCHOLOGICAL-FIRST-AID"
place_doc "RADIO-GUIDE"           "$ROOT/Manuals/Radio-Communications/RADIO-GUIDE"
place_doc "RADIO-FREQUENCIES"     "$ROOT/Manuals/Radio-Communications/RADIO-FREQUENCIES"
place_doc "HOW-TO-VIEW-MAPS"      "$ROOT/OsmAnd/HOW-TO-VIEW-MAPS"
place_doc "MAP-AND-COMPASS"       "$ROOT/OsmAnd/MAP-AND-COMPASS"
place_doc "USE-ON-PHONE"          "$ROOT/Phone-Apps/USE-ON-PHONE"
place_doc "Education-READ-ME-FIRST" "$ROOT/Education/READ-ME-FIRST"
place_doc "HOW-TO-KOLIBRI"          "$ROOT/Education/HOW-TO-KOLIBRI"
fi

# ================================================================ manual Q&A
DOC_QA_FAILED=0
if [ -z "$ONLY" ]; then
  setup="$SCRIPTDIR/doc-qa/install.sh"
  if [ ! -f "$setup" ]; then
    setup="$ROOT/AI-Offline/install-doc-qa.sh"
    rm -f "$setup"
    # Not fetch: a failed helper download must not fail a library that otherwise installed.
    get_repo doc-qa/install.sh "$setup" 2>/dev/null || true
  fi
  if [ -s "$setup" ]; then
    . "$setup"
    install_manual_qa "$ROOT" "$SCRIPTDIR" "$REPO_RAW" || DOC_QA_FAILED=1
  else log "doc-QA ERROR: setup helper missing"; DOC_QA_FAILED=1; fi
fi

# CHECK-DRIVE scripts (#28), placed before the index so README.html lists them.
for f in CHECK-DRIVE.sh check-drive.ps1 CHECK-DRIVE.bat; do
  if [ -f "$SCRIPTDIR/drive/$f" ]; then cp "$SCRIPTDIR/drive/$f" "$ROOT/$f"
  else get_repo "drive/$f" "$ROOT/$f" || { log "ERROR: download failed: drive/$f"; exit 1; }; fi
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
  find "$ROOT" -type f ! -name '._*' -name '*.html' ! -name 'README.html' | sort | while read -r f; do
    rel="$(relp "$f")"; dir="$(dirname "$rel")"; [ "$dir" = "." ] && dir='(root)'
    mdrel="${rel%.html}.md"; ml=""; [ -f "$ROOT/$mdrel" ] && ml=" &middot; <a href='$mdrel'>md</a>"
    printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$dir</td><td><a href='$rel'>HTML</a>$ml</td></tr>"
  done
  printf '%s' "</table>"
  # pdfs
  if find "$ROOT" -type f ! -name '._*' -name '*.pdf' | grep -q .; then
    printf '%s' "<h2>&#128218; Manuals &amp; Books (PDF)</h2><table><tr><th>Document</th><th>Folder</th><th>Size</th><th>Open</th></tr>"
    find "$ROOT" -type f ! -name '._*' -name '*.pdf' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td><td><a href='$rel'>PDF</a></td></tr>"; done
    printf '%s' "</table>"
  fi
  # zims
  if find "$ROOT" -type f ! -name '._*' -name '*.zim' | grep -q .; then
    printf '%s' "<h2>&#127760; Offline Archives (ZIM &mdash; open with Kiwix)</h2><table><tr><th>Archive</th><th>Folder</th><th>Size</th><th>File</th></tr>"
    find "$ROOT" -type f ! -name '._*' -name '*.zim' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td>$(nicen "$f")</td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td><td><a href='$rel'>open</a></td></tr>"; done
    printf '%s' "</table>"
  fi
  # programs
  printf '%s' "<h2>&#9881; Programs &amp; Launchers</h2><table><tr><th>Item</th><th>Folder</th></tr>"
  { find "$ROOT" -type f ! -name '._*' \( -name '*.bat' -o -name '*.sh' -o -name '*.command' -o -name '*.appimage' -o -name '*.run' -o -name '*.dmg' \); find "$ROOT" -type f ! -name '._*' -name '*.exe' | grep -iE 'installer|kiwix-desktop'; } | sort -u | while read -r f; do rel="$(relp "$f")"; dir="$(dirname "$rel")"; [ "$dir" = "." ] && dir='(root)'; printf '%s' "<tr><td><a href='$rel'>$(basename "$f")</a></td><td class='muted'>$dir</td></tr>"; done
  printf '%s' "</table>"
  # apks
  if find "$ROOT" -type f ! -name '._*' -name '*.apk' | grep -q .; then
    printf '%s' "<h2>&#128241; Phone Apps (Android APK)</h2><table><tr><th>App</th><th>Folder</th><th>Size</th></tr>"
    find "$ROOT" -type f ! -name '._*' -name '*.apk' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td><a href='$rel'>$(basename "$f")</a></td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td></tr>"; done
    printf '%s' "</table>"
  fi
  # data
  if find "$ROOT" -type f ! -name '._*' \( -name '*.bz2' -o -name '*.obf.zip' \) | grep -q .; then
    printf '%s' "<h2>&#128451; Data</h2><table><tr><th>Item</th><th>Folder</th><th>Size</th></tr>"
    find "$ROOT" -type f ! -name '._*' -name '*.bz2' | sort | while read -r f; do rel="$(relp "$f")"; printf '%s' "<tr><td>$(basename "$f") <span class='muted'>(Wikipedia)</span></td><td class='muted'>$(dirname "$rel")</td><td>$(hsz "$f")</td></tr>"; done
    mc=$(find "$ROOT" -type f ! -name '._*' -name '*.obf.zip' | wc -l | tr -d ' ')
    [ "$mc" -gt 0 ] && printf '%s' "<tr><td>Offline maps (OsmAnd) - $mc files</td><td class='muted'>OsmAnd</td><td>$(du -ch "$ROOT"/OsmAnd/*.obf.zip 2>/dev/null | tail -1 | cut -f1)</td></tr>"
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
# --only (#195): hash only what the pieces write (RH, paths as "./..."), plus any file the old
# list lacks; keep every other line; files that are gone drop out. Not by modification time:
# unzip and tar restore an archive's old times. Get-OfflineLibrary.ps1 builds the same RH.
OLD_SUMS=""; RH='README\.html|CHECK-DRIVE\.(sh|command|bat)|check-drive\.ps1'
if [ -n "${ONLY:-}" ] && [ -f "$ROOT/CHECKSUMS-SHA256.txt" ]; then
  OLD_SUMS="$ROOT/CHECKSUMS-SHA256.txt"
  for p in $ONLY; do case "$p" in
    translate) RH="$RH|AI-Offline/[^/]+|AI-Offline/models/$TR_MODEL" ;;
    medlineplus) RH="$RH|Medical/MedlinePlus/.*" ;;
    extra-zims) RH="$RH|Extra-Archives/.*" ;;
    browser-maps) RH="$RH|Maps-Browser/.*" ;;
    education) RH="$RH|Education/KhanAcademy/.*" ;;
    kolibri) RH="$RH|Education/Kolibri/.*|Phone-Apps/.*" ;;
    wikipedia) RH="$RH|Wikipedia/.*" ;;
  esac; done
  log "Hashing only the files --only wrote ($ONLY); the other lines are kept..."
else log "Hashing every file (one pass over the whole drive - this can take a while)..."; fi
# ENVIRON, not -v: awk -v would turn the regex's \. into a plain dot.
( cd "$ROOT" && find . -type f \
    ! -name 'CHECKSUMS-SHA256.txt*' ! -name '_download.log' ! -name '_filelist.txt' ! -name '_index.xml' \
    ! -name '*.part' ! -name '*.aria2' ! -name '._*' ! -name '.DS_Store' \
    ! -path './.Spotlight-V100/*' ! -path './.fseventsd/*' ! -path './.Trashes/*' ! -path './System Volume Information/*' |
  LC_ALL=C sort | OLD="$OLD_SUMS" RE="^\\./($RH)\$" awk '
    BEGIN { if (ENVIRON["OLD"] != "") while ((getline l < ENVIRON["OLD"]) > 0) k[substr(l, 67)] = l }
    ($0 in k) && $0 !~ ENVIRON["RE"] { print "K" k[$0]; next } { print "H" $0 }' |
  while IFS= read -r f; do
    case "$f" in K*) printf '%s\n' "${f#K}" ;; *) $SHA "${f#H}" || echo "${f#H}" >&2 ;; esac
  done ) > "$ROOT/CHECKSUMS-SHA256.txt.new" 2> "$ROOT/CHECKSUMS-SHA256.txt.err"
if [ -s "$ROOT/CHECKSUMS-SHA256.txt.err" ]; then
  log "ERROR: could not read these files for the checksum list: $(tr '\n' ' ' < "$ROOT/CHECKSUMS-SHA256.txt.err")"; exit 1
fi
rm -f "$ROOT/CHECKSUMS-SHA256.txt.err"; mv -f "$ROOT/CHECKSUMS-SHA256.txt.new" "$ROOT/CHECKSUMS-SHA256.txt"
log "CHECKSUMS-SHA256.txt: $(grep -c . "$ROOT/CHECKSUMS-SHA256.txt") files. Run CHECK-DRIVE every few months."

# ================================================================ self-check (#30)
# Read-only checks of what was built, so a broken kit never ends with a bare DONE.
# Writes nothing to the drive (CHECKSUMS-SHA256.txt above stays correct).
log "=== Self-check ==="
SC_FAIL=0
sc_pass(){ log "  PASS  $*"; }
sc_warn(){ log "  WARN  $*"; }
sc_fail(){ log "  FAIL  $*"; SC_FAIL=$((SC_FAIL+1)); }
[ "$DOC_QA_FAILED" = 0 ] || sc_warn "manual Q&A source coverage is incomplete (see doc-QA lines above); those PDFs still open directly"
E="$ROOT/AI-Offline/engine"
# 1. Every engine folder has its program (a failed unpack leaves a folder empty).
if [ -f "$E/BUILD.txt" ]; then
  miss=""
  for x in $LLAMA_ASSETS; do
    d="${x##*:}"; case "$d" in x64|arm64|vulkan-x64) t=llama-cli.exe;; *) t=llama-cli;; esac
    [ -n "$(find "$E/$d" -name "$t" -type f 2>/dev/null | head -n1)" ] || miss="$miss $d"
  done
  if [ -z "$miss" ]; then sc_pass "AI engine $(cat "$E/BUILD.txt") is on the drive for all 8 platforms"
  else sc_fail "AI engine program missing in engine/:$miss (re-run the installer)"; fi
else
  sc_fail "AI engine was not downloaded (see the [1/8] lines above)"
fi
# 2. The engine starts on this computer: same folder and library path as the launchers.
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) P=macos-arm64 ;;
  Darwin-*) P=macos-x64 ;;
  Linux-aarch64|Linux-arm64) P=linux-arm64 ;;
  *) P=linux-x64 ;;
esac
BIN="$(find "$E/$P" -name llama-cli -type f 2>/dev/null | head -n1)"
if [ -n "$BIN" ]; then
  chmod +x "$BIN" 2>/dev/null
  LIBDIR="$(dirname "$BIN")"
  out="$(LD_LIBRARY_PATH="$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" DYLD_LIBRARY_PATH="$LIBDIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$BIN" --version 2>&1)"; rc=$?
  if [ "$rc" = 0 ]; then
    sc_pass "AI engine starts on this computer ($P): $(printf '%s\n' "$out" | grep -m1 '^version' | cut -c1-80)"
  else
    why="$(printf '%s\n' "$out" | grep -m1 -iE 'error|not found|not loaded|denied' | cut -c1-200)"
    sc_fail "AI engine does not start on this computer ($P): ${why:-exit code $rc}"
    case "$out" in
      *libgomp.so*) log "        Fix: install the GNU OpenMP library (Debian/Ubuntu: sudo apt install libgomp1). The drive itself is fine." ;;
      *"shared libraries: libllama"*|*"shared libraries: libggml"*|*"shared libraries: libmtmd"*) log "        That library is part of the engine on the drive. Re-run the installer to unpack the engine again." ;;
      *"shared libraries"*) log "        Fix: install the library named above with this computer's package manager. The drive itself is fine." ;;
      *"Library not loaded"*) log "        A file of the engine is missing on the drive. Re-run the installer to unpack the engine again." ;;
      *GLIBC*) log "        This Linux is too old for this AI build (it needs a newer glibc/libstdc++; on ARM: Debian 13 or Ubuntu 24.04 or newer). The drive still works on newer computers." ;;
      *"ermission denied"*) log "        The drive may be mounted 'noexec'. Remount it with exec, or copy AI-Offline to this computer's own disk." ;;
    esac
  fi
elif [ -f "$E/BUILD.txt" ]; then
  log "  (engine start test skipped: no engine/$P program, see the FAIL above)"
fi
# 3. Every ZIM has the ZIM magic number and its full size. The header says where the
#    file's closing 16-byte MD5 starts, so a cut-off download is caught. (A file of the
#    right size with damaged insides is not: that needs a full read.)
zt=0; zbad=""
while IFS= read -r f; do
  [ -n "$f" ] || continue; zt=$((zt+1))
  m="$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')"
  cs="$(od -An -t u8 -j 72 -N 8 "$f" 2>/dev/null | tr -d ' \n')"
  sz="$(wc -c < "$f" | tr -d ' ')"
  if [ "$m" != 5a494d04 ] || [ -z "$cs" ] || [ "$sz" != "$((cs + 16))" ]; then zbad="$zbad
        $(relp "$f")"; fi
done <<ZEOF
$(find "$ROOT" -type f ! -name '._*' -name '*.zim' | LC_ALL=C sort)
ZEOF
if [ "$zt" = 0 ]; then sc_warn "no Kiwix archives (.zim) found"
elif [ -z "$zbad" ]; then sc_pass "$zt Kiwix archives (.zim): header and size OK"
else sc_fail "Kiwix archive(s) not a ZIM or not complete - delete each one and re-run the installer:$zbad"; fi
# 4. Every PDF starts with %PDF.
pt=0; pbad=""
while IFS= read -r f; do
  [ -n "$f" ] || continue; pt=$((pt+1))
  [ "$(head -c 4 "$f" 2>/dev/null)" = "%PDF" ] || pbad="$pbad
        $(relp "$f")"
done <<PEOF
$(find "$ROOT" -type f ! -name '._*' -name '*.pdf' | LC_ALL=C sort)
PEOF
if [ "$pt" = 0 ]; then sc_warn "no PDF manuals found"
elif [ -z "$pbad" ]; then sc_pass "$pt PDF files: all start with %PDF"
else sc_fail "file(s) named .pdf that are not PDFs - delete each one and re-run the installer:$pbad"; fi
# 5. Every AI model (.gguf) has the size and SHA-256 that Hugging Face publishes, so a cut-off
#    download is caught (#71). The hash is the one just written to CHECKSUMS-SHA256.txt: no extra read.
gt=0; gbad=""; gwarn=""
for u in $GGUF_URLS; do
  n="${u##*/}"; f="$ROOT/AI-Offline/models/$n"
  [ -f "$f" ] || continue; gt=$((gt+1))
  if [ -e "$f.aria2" ]; then gbad="$gbad
        AI-Offline/models/$n (download not finished)"; continue; fi
  hd="$(curl -sI --max-time 30 "$u" 2>/dev/null | tr -d '\r')"
  want="$(printf '%s\n' "$hd" | grep -i '^x-linked-size:' | head -n1 | tr -dc '0-9')"
  wsha="$(printf '%s\n' "$hd" | grep -i '^x-linked-etag:' | head -n1 | grep -oE '[0-9a-f]{64}')"
  have="$(awk -v p="./AI-Offline/models/$n" 'substr($0,67)==p{print substr($0,1,64); exit}' "$ROOT/CHECKSUMS-SHA256.txt")"
  sz="$(wc -c < "$f" | tr -d ' ')"
  if [ -z "$want" ]; then gwarn="$gwarn $n"
  elif [ "$sz" != "$want" ]; then gbad="$gbad
        AI-Offline/models/$n ($sz of $want bytes)"
  elif [ -n "$wsha" ] && [ "$have" != "$wsha" ]; then gbad="$gbad
        AI-Offline/models/$n (SHA-256 does not match Hugging Face)"
  fi
done
if [ "$gt" = 0 ]; then sc_warn "no AI models (.gguf) found"
elif [ -n "$gbad" ]; then sc_fail "AI model(s) not complete or damaged - delete each one and re-run the installer:$gbad"
elif [ -n "$gwarn" ]; then sc_warn "could not reach Hugging Face to check these AI models (not verified):$gwarn"
else sc_pass "$gt AI models (.gguf): size and SHA-256 match Hugging Face"; fi

# 6. Desktop map viewers (OffRoad and OsmAndMapCreator + portable Java runtime)
MVD="$ROOT/OsmAnd/MapViewer-Desktop"
if [ "$SKIP_MAPS" = 0 ]; then
  BAT="$MVD/app/OsmAndMapCreator.sh"
  OFFJAR="$MVD/offroad/OffRoad.jar"
  OFFBAT="$MVD/VIEW-MAPS-OFFLINE.sh"
  JRE="$(find "$MVD/jre" -name java -type f 2>/dev/null | head -n1)"
  if [ -f "$BAT" ] && [ -f "$OFFJAR" ] && [ -f "$OFFBAT" ] && [ -n "$JRE" ]; then
    sc_pass "desktop map viewers (OffRoad + OsmAndMapCreator + Java runtime) ready"
  else
    mv_miss=""
    [ -f "$BAT" ] || mv_miss="$mv_miss app/OsmAndMapCreator.sh"
    [ -f "$OFFBAT" ] || mv_miss="$mv_miss VIEW-MAPS-OFFLINE.sh"
    [ -n "$JRE" ] || mv_miss="$mv_miss jre/bin/java"
    if [ -n "$mv_miss" ]; then
      sc_fail "desktop map viewers not complete - missing:$mv_miss - delete OsmAnd/MapViewer-Desktop/OsmAndMapCreator.zip (or the Java archive) and re-run the installer"
    elif [ ! -f "$OFFJAR" ]; then
      sc_warn "optional OffRoad viewer was not downloaded - delete OsmAnd/MapViewer-Desktop/OffRoad.zip and re-run the installer to retry"
    fi
  fi
elif [ -d "$MVD" ]; then
  if [ -n "$ONLY" ]; then
    sc_warn "desktop map viewer not part of this run"
  else
    sc_warn "desktop map viewer skipped (--skip-maps)"
  fi
fi

if [ "$GUIDED" = 1 ]; then echo ""; echo "  The same install as one command: $GUIDED_CMD"; fi
if [ "$SC_FAIL" = 0 ]; then
  log "=== DONE. Open README.html (full index) or START-HERE.html ==="
  echo ""
  echo "  Finished. Your offline library is in: $ROOT"
  echo "  Open README.html for a full index, or START-HERE.html to begin."
else
  log "=== FINISHED WITH PROBLEMS: $SC_FAIL self-check(s) failed - see the FAIL lines above ==="
  echo ""
  echo "  Your offline library is in: $ROOT"
  echo "  Fix the FAIL line(s) above before you rely on it."
  exit 1
fi

#!/usr/bin/env bash
# Called by get-offline-library.sh with its existing fetch and log helpers.
doc_qa_download(){ # url target - non-fatal, unlike the installer's fetch
  # 6 tries, 3 s apart; a try with no data for a minute is cut off. Not curl's --retry, which
  # sleeps as long as a server's Retry-After asks (#302).
  local part="$2.new" try=1
  while :; do
    rm -f "$part"
    if curl -fL --speed-limit 1 --speed-time 60 -sS -o "$part" "$1" && [ -s "$part" ]; then
      mv -f "$part" "$2"; return 0
    fi
    [ "$try" -lt 6 ] || break
    try=$((try+1)); sleep 3
  done
  rm -f "$part"; return 1
}
install_manual_qa(){
  local root="$1" src="$2" out base name target line pdf algorithm pdfhash url texthash mode unused path text actual
  out="$root/AI-Offline/Manual-QA"
  # The installer passes its repo base (pinned to one commit, #193); main if it does not.
  base="${3:-https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main}/doc-qa"
  mkdir -p "$out/text"
  for name in index.html reader.css reader.mjs retrieval.mjs START-DOCS.bat start-docs.sh sources.tsv; do
    target="$out/$name"
    if [ -f "$src/doc-qa/$name" ]; then cp "$src/doc-qa/$name" "$target"
    else
      doc_qa_download "$base/$name" "$target" || { log "doc-QA ERROR: reader asset unavailable: $name"; return 1; }
    fi
  done
  tr -d '\r' < "$out/START-DOCS.bat" | sed 's/$/\r/' > "$out/START-DOCS.bat.new" && mv -f "$out/START-DOCS.bat.new" "$out/START-DOCS.bat"
  : > "$out/ready.tsv"; : > "$out/missing.txt"
  while IFS=$'\t' read -r pdf algorithm pdfhash url texthash mode unused; do
    case "$pdf" in ''|\#*) continue ;; esac
    case "$pdf" in Medical/Manuals-PDF/*.pdf|Manuals/ArmyFieldManuals/*.pdf|Manuals/Food-Growing/*.pdf|Manuals/Metalworking/*.pdf|Manuals/Survival-Preparedness/*.pdf) ;; *) log "doc-QA ERROR: invalid PDF path"; return 1 ;; esac
    case "$pdf" in *..*|*\\*) log "doc-QA ERROR: unsafe PDF path"; return 1 ;; esac
    [[ "$texthash" =~ ^[a-f0-9]{64}$ ]] || { log "doc-QA ERROR: invalid text hash"; return 1; }
    case "$mode" in pages|excerpts) ;; *) log "doc-QA ERROR: invalid text mode"; return 1 ;; esac
    path="$root/$pdf"; actual=""
    if [ -f "$path" ]; then
      case "$algorithm" in
        MD5) if command -v md5sum >/dev/null 2>&1; then actual="$(md5sum "$path" | cut -d' ' -f1)"; else actual="$(md5 -q "$path")"; fi ;;
        SHA256) if command -v sha256sum >/dev/null 2>&1; then actual="$(sha256sum "$path" | cut -d' ' -f1)"; else actual="$(shasum -a 256 "$path" | cut -d' ' -f1)"; fi ;;
        *) log "doc-QA ERROR: invalid PDF hash algorithm"; return 1 ;;
      esac
    fi
    if [ "$actual" != "$pdfhash" ]; then printf '%s\n' "$pdf - PDF missing or changed; text needs refreshing" >> "$out/missing.txt"; continue; fi
    text="$out/text/$texthash.txt"; actual=""
    if [ -f "$text" ]; then
      if command -v sha256sum >/dev/null 2>&1; then actual="$(sha256sum "$text" | cut -d' ' -f1)"; else actual="$(shasum -a 256 "$text" | cut -d' ' -f1)"; fi
    fi
    if [ "$actual" != "$texthash" ]; then
      rm -f "$text"
      case "$url" in
        text/*) if [ -f "$src/doc-qa/$url" ]; then cp "$src/doc-qa/$url" "$text"; else doc_qa_download "$base/$url" "$text" || true; fi ;;
        https://archive.org/download/*) doc_qa_download "$url" "$text" || true ;;
        *) log "doc-QA ERROR: unexpected text host"; return 1 ;;
      esac
    fi
    actual=""
    if [ -f "$text" ]; then
      if command -v sha256sum >/dev/null 2>&1; then actual="$(sha256sum "$text" | cut -d' ' -f1)"; else actual="$(shasum -a 256 "$text" | cut -d' ' -f1)"; fi
    fi
    if [ "$actual" != "$texthash" ]; then printf '%s\n' "$pdf - source text download failed or changed" >> "$out/missing.txt"; continue; fi
    printf '%s\ttext/%s.txt\t%s\n' "$pdf" "$texthash" "$mode" >> "$out/ready.tsv"
  done < <(tr -d '\r' < "$out/sources.tsv")
  cp "$out/start-docs.sh" "$out/start-docs.command"   # macOS double-click
  chmod +x "$out/start-docs.sh" "$out/start-docs.command"
  if [ -s "$out/missing.txt" ]; then
    while IFS= read -r line; do log "doc-QA WARN: $line"; done < "$out/missing.txt"
    return 1
  fi
  if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
    log "doc-QA: manuals ready. Run AI-Offline/Manual-QA/start-docs.command."
  else
    log "doc-QA: manuals ready. Run AI-Offline/Manual-QA/start-docs.sh."
  fi
}

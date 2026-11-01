#!/bin/bash
# OPEN-LIBRARY - opens every offline archive (.zim) on this drive in your web browser.
# Works on macOS (double-click OPEN-LIBRARY.command) and Linux (run: bash OPEN-LIBRARY.sh).
# Nothing is installed. Close this window to stop the library.
cd "$(dirname "$0")" || exit 1
PORT=8095
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)               P=macos-arm64 ;;
  Darwin-*)                   P=macos-x86_64 ;;
  Linux-aarch64|Linux-arm64)  P=linux-aarch64 ;;
  *)                          P=linux-x86_64 ;;
esac
KS="$(find "Kiwix-Reader/tools/$P" -name kiwix-serve -type f 2>/dev/null | head -n1)"
KM="$(find "Kiwix-Reader/tools/$P" -name kiwix-manage -type f 2>/dev/null | head -n1)"
if [ -z "$KS" ] || [ -z "$KM" ]; then
  echo "The library reader for this computer ($P) is missing from Kiwix-Reader/tools/."
  read -r -p "Press Enter to close. " _; exit 1
fi
chmod +x "$KS" "$KM" 2>/dev/null
LIB="${TMPDIR:-/tmp}/offline-library-$$.xml"
echo "Finding archives on the drive..."
n=0
while IFS= read -r z; do
  "$KM" "$LIB" add "$z" >/dev/null 2>&1 && n=$((n+1))
done < <(find "$PWD" -name '*.zim' -type f ! -name '._*' | sort)
if [ "$n" = 0 ]; then echo "No .zim archives found."; read -r -p "Press Enter to close. " _; exit 1; fi
echo "Opening $n archives at http://localhost:$PORT  (close this window to stop)"
( sleep 3; open "http://localhost:$PORT" 2>/dev/null || xdg-open "http://localhost:$PORT" >/dev/null 2>&1 ) &
exec "$KS" --address=127.0.0.1 --port="$PORT" --library "$LIB"

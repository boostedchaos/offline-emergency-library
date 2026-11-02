#!/bin/bash
# OPEN-MAPS - offline street maps of the US in your web browser (macOS: double-click
# OPEN-MAPS.command; Linux: bash OPEN-MAPS.sh). Nothing is installed. Close this window to stop.
cd "$(dirname "$0")" || exit 1
PORT=8097
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)              P=mac-arm64 ;;
  Darwin-*)                  P=mac-amd64 ;;
  Linux-aarch64|Linux-arm64) P=linux-arm64 ;;
  *)                         P=linux-amd64 ;;
esac
C="$(find "Maps-Browser/server/$P" -name caddy -type f 2>/dev/null | head -n1)"
if [ -z "$C" ] || [ ! -f Maps-Browser/regions.json ]; then
  echo "The browser maps or their web server for this computer ($P) are missing from Maps-Browser/."
  read -r -p "Press Enter to close. " _; exit 1
fi
chmod +x "$C" 2>/dev/null
echo "Opening the maps at http://localhost:$PORT/viewer/  (close this window to stop)"
( sleep 2; open "http://localhost:$PORT/viewer/" 2>/dev/null || xdg-open "http://localhost:$PORT/viewer/" >/dev/null 2>&1 ) &
exec "$C" file-server --root "$PWD/Maps-Browser" --listen "127.0.0.1:$PORT"

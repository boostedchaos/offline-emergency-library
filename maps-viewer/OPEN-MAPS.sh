#!/usr/bin/env bash
# OPEN-MAPS (macOS / Linux): offline street maps in your web browser. Nothing is installed.
# Run:  bash OPEN-MAPS.sh   (in the Maps-Browser folder). Close this window to stop.
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8097
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) P=mac-arm64 ;;
  Darwin-*) P=mac-amd64 ;;
  Linux-aarch64|Linux-arm64) P=linux-arm64 ;;
  *) P=linux-amd64 ;;
esac
C="$(find "$DIR/server/$P" -name caddy -type f 2>/dev/null | head -n1)"
if [ -z "$C" ] || [ ! -f "$DIR/regions.json" ]; then
  echo "The maps or their web server for this computer ($P) are missing from $DIR"
  exit 1
fi
chmod +x "$C" 2>/dev/null
echo "Opening the maps at http://localhost:$PORT/viewer/  (close this window to stop)"
( sleep 2; open "http://localhost:$PORT/viewer/" 2>/dev/null || xdg-open "http://localhost:$PORT/viewer/" >/dev/null 2>&1 ) &
exec "$C" file-server --root "$DIR" --listen "127.0.0.1:$PORT"

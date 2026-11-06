#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) engine=macos-arm64 ;;
  Darwin/x86_64) engine=macos-x64 ;;
  Linux/aarch64|Linux/arm64) engine=linux-arm64 ;;
  Linux/x86_64) engine=linux-x64 ;;
  *) echo "Unsupported system. Open the PDFs directly."; exit 1 ;;
esac
echo "Open http://127.0.0.1:8081/AI-Offline/Manual-QA/ when the server is ready."
echo "Keep this window open. Press Ctrl+C to stop."
# The macOS and Linux engine archives unpack into a version folder (engine/<platform>/llama-bNNNNN/).
BIN="$(find "$HERE/../engine/$engine" -name llama-server -type f 2>/dev/null | head -n1)"
[ -n "$BIN" ] || { echo "AI engine for this computer not found: $HERE/../engine/$engine. Re-run the installer."; exit 1; }
chmod +x "$BIN" 2>/dev/null || true
LIBDIR="$(dirname "$BIN")"
export LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="$LIBDIR:${DYLD_LIBRARY_PATH:-}"
exec "$BIN" -m "$HERE/../models/Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096 -ngl 0 -t 4 --offline --host 127.0.0.1 --port 8081 --path "$HERE/../.."

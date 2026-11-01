#!/bin/bash
# AI-CHAT - offline AI chat in your web browser (macOS: double-click AI-CHAT.command;
# Linux: bash AI-CHAT.sh). Nothing is installed. Close this window to stop the AI.
# You can attach PDFs and text files in the chat; the AI answers from them.
cd "$(dirname "$0")" || exit 1
PORT=8098
SMALL="AI-Offline/models/Qwen3.5-4B-Q4_K_M.gguf"
MEDIUM="AI-Offline/models/gemma-4-12b-it-qat-q4_0.gguf"
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)              P=macos-arm64 ;;
  Darwin-*)                  P=macos-x64 ;;
  Linux-aarch64|Linux-arm64) P=ubuntu-arm64 ;;
  *)                         P=ubuntu-x64 ;;
esac
echo "Offline AI chat"
echo "  1 = Small  (Qwen 3.5 4B)  - fast, needs about 8 GB of memory"
echo "  2 = Medium (Gemma 4 12B)  - better answers, needs about 16 GB of memory"
[ "$P" = ubuntu-x64 ] && echo "  3 = Small on the graphics card (GPU)" && echo "  4 = Medium on the graphics card (GPU)"
read -r -p "Type a number and press Enter [1]: " c
GPU=""
case "$c" in
  2) MODEL="$MEDIUM" ;;
  3) MODEL="$SMALL";  P=ubuntu-vulkan-x64; GPU="-ngl 99" ;;
  4) MODEL="$MEDIUM"; P=ubuntu-vulkan-x64; GPU="-ngl 99" ;;
  *) MODEL="$SMALL" ;;
esac
if [ ! -f "$MODEL" ]; then echo "That model is not on this drive: $MODEL"; read -r -p "Press Enter to close. " _; exit 1; fi
SRV="$(find "AI-Offline/engine/$P" -name llama-server -type f 2>/dev/null | head -n1)"
if [ -z "$SRV" ]; then echo "The AI program for this computer ($P) is missing from AI-Offline/engine/."; read -r -p "Press Enter to close. " _; exit 1; fi
LIBDIR="$(cd "$(dirname "$SRV")" && pwd)"
chmod +x "$SRV" 2>/dev/null
export LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="$LIBDIR:${DYLD_LIBRARY_PATH:-}"
echo "Loading the model (can take up to a minute from the drive)..."
echo "Your browser opens at http://localhost:$PORT when it is ready. Close this window to stop."
( for i in $(seq 1 180); do
    if curl -s -m 2 "http://127.0.0.1:$PORT/health" | grep -q '"ok"'; then
      open "http://localhost:$PORT" 2>/dev/null || xdg-open "http://localhost:$PORT" >/dev/null 2>&1; break
    fi; sleep 1
  done ) &
exec "$SRV" -m "$MODEL" -c 8192 $GPU --host 127.0.0.1 --port "$PORT"

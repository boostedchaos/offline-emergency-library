#!/bin/bash
# Phase 1 setup (macOS arm64): llama.cpp b12638 (macos-arm64) + the 3 OEL chat models, SHA-256 checked against Hugging Face.
set -euo pipefail
H="${WORKDIR:-$PWD}"; mkdir -p "$H/models" "$H/engine"
cd "$H"
LT=b12638
curl -fL --retry 5 -o "engine/llama-$LT-bin-macos-arm64.tar.gz" "https://github.com/ggml-org/llama.cpp/releases/download/$LT/llama-$LT-bin-macos-arm64.tar.gz"
tar -xzf "engine/llama-$LT-bin-macos-arm64.tar.gz" -C engine
HF=https://huggingface.co/bartowski
while read -r repo f sha; do
  curl -fL --retry 5 -C - -o "models/$f" "$HF/$repo/resolve/main/$f"
  got="$(shasum -a 256 "models/$f" | cut -d' ' -f1)"
  if [ "$got" = "$sha" ]; then echo "SHA OK $f $got"; else echo "SHA BAD $f got $got want $sha"; exit 3; fi
done <<'M'
Llama-3.2-3B-Instruct-GGUF Llama-3.2-3B-Instruct-Q4_K_M.gguf 6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff
Meta-Llama-3.1-8B-Instruct-GGUF Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf 7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
Qwen2.5-7B-Instruct-GGUF Qwen2.5-7B-Instruct-Q4_K_M.gguf 65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423
M

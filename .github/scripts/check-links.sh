#!/usr/bin/env bash
# Verifies that every upstream source the installers depend on still resolves.
# Used by CI (weekly + on push) to catch a provider changing a path before users do.
set -u
fail=0

# plain URL checks (expect 2xx/3xx after following redirects)
urls=(
  "https://download.osmand.net/get_indexes"
  "https://download.kiwix.org/zim/ifixit/"
  "https://download.kiwix.org/zim/other/"
  "https://download.kiwix.org/zim/wikipedia/"
  "https://download.kiwix.org/release/kiwix-desktop/"
  "https://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip"
  "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jre/hotspot/normal/eclipse"
  "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF"
  "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF"
  "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF"
  "https://f-droid.org/api/v1/packages/net.osmand.plus"
  "https://archive.org/metadata/fm-21-76-us-army-survival-manual"
)

check() { # url
  local code
  code=$(curl -s -L -o /dev/null -w '%{http_code}' --max-time 45 -A "oel-ci" "$1")
  if [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
    echo "  OK  ($code)  $1"
  else
    echo "  FAIL ($code) $1"; fail=1
  fi
}

echo "== Upstream download sources =="
for u in "${urls[@]}"; do check "$u"; done

# GitHub release APIs (use token to avoid rate limits; verify a matching asset exists)
echo "== GitHub release assets =="
gh_hdr=(-H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && gh_hdr+=(-H "Authorization: Bearer $GITHUB_TOKEN")

gh_has_asset() { # repo  releases-path  regex  label
  local body
  body=$(curl -s "${gh_hdr[@]}" --max-time 45 "https://api.github.com/repos/$1/$2")
  if printf '%s' "$body" | grep -oE '"browser_download_url": *"[^"]+"' | grep -qE "$3"; then
    echo "  OK   $4"
  else
    echo "  FAIL $4 (no asset matching /$3/)"; fail=1
  fi
}
gh_has_asset "ggml-org/llama.cpp"   "releases?per_page=20" "bin-win-cpu-x64\\.zip"        "llama.cpp Windows CPU build"
gh_has_asset "ggml-org/llama.cpp"   "releases?per_page=20" "bin-ubuntu-x64\\.tar\\.gz"    "llama.cpp Linux build"
gh_has_asset "nomic-ai/gpt4all"     "releases/latest"      "installer-win64-v.*\\.exe"    "GPT4All Windows installer"
gh_has_asset "kiwix/kiwix-android"  "releases/latest"      "universal-standalone\\.apk"   "Kiwix Android APK"

echo ""
if [ "$fail" -ne 0 ]; then
  echo "One or more upstream sources failed. The installers may need updating."
  exit 1
fi
echo "All upstream sources resolve."

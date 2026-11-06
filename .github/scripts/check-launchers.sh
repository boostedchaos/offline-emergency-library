#!/usr/bin/env bash
# Launcher parity: get-offline-library.sh and Get-OfflineLibrary.ps1 must write the same
# AI-Offline launchers (.sh and .bat), so a drive built on any OS works on every OS.
# Runs only the launcher section of each installer into a temp folder (no downloads),
# for the full and the --lite / -Lite set, and compares the files byte for byte.
# Needs bash, pwsh and perl. Used by CI (lint job).
set -u
cd "$(dirname "$0")/../.." || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0

# The section starts where the launchers are written and ends at the documentation step.
sed -n '/^AO="\$ROOT\/AI-Offline"/,/^# =* documentation/p' get-offline-library.sh > "$T/sec.sh"
# CRLF like a Windows checkout (.gitattributes: *.ps1 eol=crlf), whatever this checkout has.
sed -n '/^function WriteBat/,/^# =* documentation/p' Get-OfflineLibrary.ps1 | tr -d '\r' | sed 's/$/\r/' > "$T/sec.ps1"
for f in sec.sh sec.ps1; do
  n=$(grep -c . "$T/$f")
  # Both ends must be found: without the end marker sed runs to the end of the file,
  # and this check would run the whole installer (downloads included).
  if [ "$n" -lt 20 ] || ! tail -n 1 "$T/$f" | grep -q '^# =* documentation'; then
    echo "FAIL: launcher section not found in the installer ($f: $n lines). Were its markers renamed?"; exit 1
  fi
done

# Read the model name from production code rather than keeping another copy.
eval "$(grep -m1 '^TR_MODEL=' get-offline-library.sh)"
for translate in 0 1; do
for lite in 0 1; do
  sh_out="$T/sh-tr$translate-lite$lite/AI-Offline"; ps_out="$T/ps-tr$translate-lite$lite/AI-Offline"
  mkdir -p "$sh_out" "$ps_out"
  ( set +u; ROOT="$T/sh-tr$translate-lite$lite"; LITE=$lite; TRANSLATE=$translate; log(){ :; }; . "$T/sec.sh" ) || { echo "FAIL: bash launcher section exited non-zero (lite=$lite translate=$translate)"; fail=1; }
  if [ "$lite" = 1 ]; then L='$true'; else L='$false'; fi
  if [ "$translate" = 1 ]; then TR='$true'; else TR='$false'; fi
  pwsh -NoProfile -NonInteractive -Command "\$ErrorActionPreference='Stop'; \$Root='$T/ps-tr$translate-lite$lite'; \$Lite=$L; \$Translate=$TR; \$TrModel='$TR_MODEL'; function Log(\$m){}; . '$T/sec.ps1'" \
    || { echo "FAIL: PowerShell launcher section exited non-zero (lite=$lite)"; fail=1; }
  # Set-Content ends a file with the OS newline: CRLF on Windows, LF here. Make the last
  # line end like it does on Windows; every other line comes from the CRLF source above.
  for b in "$ps_out"/*.bat; do [ -e "$b" ] && perl -0pi -e 's/(?<!\r)\n\z/\r\n/' "$b"; done

  ns=$(ls "$sh_out" | wc -l | tr -d ' '); np=$(ls "$ps_out" | wc -l | tr -d ' ')
  echo "== lite=$lite translate=$translate: bash wrote $ns files, PowerShell wrote $np"
  if [ "$ns" -lt 4 ] || [ "$np" -lt 4 ]; then echo "FAIL: too few launchers written (expected at least 4)"; fail=1; fi
  if diff -r "$sh_out" "$ps_out" > "$T/diff.txt"; then
    ls "$sh_out" | sed 's/^/  same: /'
  else
    echo "FAIL: the two installers write different launchers (lite=$lite):"; head -40 "$T/diff.txt"; fail=1
  fi
  # .bat must be CRLF on every line; .sh must have no CR at all.
  for b in "$sh_out"/*.bat; do [ -e "$b" ] && [ "$(grep -cE $'[^\r]$|^$' "$b")" != 0 ] && { echo "FAIL: $(basename "$b") has a line without CRLF"; fail=1; }; done
  for s in "$sh_out"/*.sh "$sh_out"/*.command; do [ -e "$s" ] && grep -q $'\r' "$s" && { echo "FAIL: $(basename "$s") has CR line ends"; fail=1; }; done
  for p in "$sh_out"/*.ps1; do [ -e "$p" ] && [ "$(grep -cE $'[^\r]$|^$' "$p")" != 0 ] && { echo "FAIL: $(basename "$p") has a line without CRLF"; fail=1; }; done
  if [ "$translate" = 0 ] && find "$sh_out" -iname '*translat*' | grep -q .; then echo "FAIL: translator must remain opt-in"; fail=1; fi
done
done

echo "== generated browser launcher readiness, engine selection and shutdown (local executable fixtures)"
W="$T/mac wrapper moved here"
mkdir -p "$W"
cp "$sh_out/translate-browser.command" "$W/"
printf '#!/usr/bin/env bash\necho invoked > wrapper-ran\nexit 17\n' > "$W/translate-browser.sh"
printf '\n' | bash "$W/translate-browser.command"; rc=$?
[ "$rc" = 17 ] && [ -s "$W/wrapper-ran" ] || { echo "FAIL: macOS wrapper lost its relative path or exit status"; fail=1; }
F="$T/moved fixture/AI-Offline"
mkdir -p "$F/models" "$T/bin"
cp "$sh_out/translate-browser.sh" "$F/"
cp "$sh_out/translate-webui.json" "$F/"
printf 'fixture model\n' > "$F/models/$TR_MODEL"
cat > "$T/bin/uname" <<'EOS'
#!/usr/bin/env bash
case "$1" in -s) echo "${OEL_PLATFORM%-*}";; -m) echo "${OEL_PLATFORM##*-}";; esac
EOS
cat > "$T/server" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$OEL_FIXTURE/args"
printf '%s\n' "$LD_LIBRARY_PATH" > "$OEL_FIXTURE/libdir"
while [ "$#" -gt 0 ]; do
  if [ "$1" = --alias ]; then echo "$2" > "$OEL_FIXTURE/alias"; fi
  shift
done
trap 'echo stopped > "$OEL_FIXTURE/stopped"; exit 0' TERM
for ((i=0; i<100; i++)); do
  [ "$OEL_CASE" = occupied ] && [ -f "$OEL_FIXTURE/polled" ] && exit 42
  sleep 0.1
done
exit 43
EOS
cat > "$T/bin/curl" <<'EOS'
#!/usr/bin/env bash
echo polled > "$OEL_FIXTURE/polled"
if [ "$OEL_CASE" = occupied ]; then echo '{"data":[{"id":"another-service"}]}'
elif [ -s "$OEL_FIXTURE/alias" ]; then printf '{"data":[{"id":"%s"}]}\n' "$(cat "$OEL_FIXTURE/alias")"
else exit 1; fi
EOS
cat > "$T/bin/open" <<'EOS'
#!/usr/bin/env bash
echo "$1" > "$OEL_FIXTURE/opened"
kill -TERM "$(cat "$OEL_FIXTURE/launcher.pid")"
EOS
cp "$T/bin/open" "$T/bin/xdg-open"
chmod +x "$T/bin/"* "$T/server"
for p in macos-arm64 macos-x64 linux-arm64 linux-x64; do
  mkdir -p "$F/engine/$p"; cp "$T/server" "$F/engine/$p/llama-server"
done
for platform in Darwin-arm64 Darwin-x86_64 Linux-aarch64 Linux-arm64 Linux-x86_64; do
  case "$platform" in Darwin-arm64) p=macos-arm64;; Darwin-*) p=macos-x64;; Linux-aarch64|Linux-arm64) p=linux-arm64;; *) p=linux-x64;; esac
  for mode in ready occupied; do
    run="$T/run-$platform-$mode"; mkdir -p "$run"
    ( export PATH="$T/bin:$PATH" OEL_PLATFORM="$platform" OEL_CASE="$mode" OEL_FIXTURE="$run"; bash "$F/translate-browser.sh" ) > "$run/output" 2>&1 &
    launcher=$!; echo "$launcher" > "$run/launcher.pid"
    wait "$launcher"; rc=$?
    if [ "$mode" = ready ]; then
      if [ "$rc" != 143 ] || [ ! -s "$run/opened" ] || [ ! -s "$run/stopped" ]; then
        echo "FAIL: $platform browser startup/shutdown (exit $rc)"; cat "$run/output"; fail=1
      fi
      grep -qF "$F/engine/$p" "$run/libdir" || { echo "FAIL: $platform selected the wrong engine"; fail=1; }
      grep -qxF 'http://127.0.0.1:8087' "$run/opened" || { echo "FAIL: browser URL"; fail=1; }
      for arg in --offline --webui-config-file "$F/translate-webui.json" "$F/models/$TR_MODEL"; do
        grep -qxF -- "$arg" "$run/args" || { echo "FAIL: missing generated server argument $arg"; fail=1; }
      done
    elif [ "$rc" != 1 ] || [ -e "$run/opened" ]; then
      echo "FAIL: $platform opened another service or hid failed startup (exit $rc)"; cat "$run/output"; fail=1
    fi
  done
done
rm "$F/models/$TR_MODEL"
out="$(PATH="$T/bin:$PATH" OEL_PLATFORM=Linux-x86_64 bash "$F/translate-browser.sh" 2>&1)"; rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q 'Translator model missing' || { echo "FAIL: missing model: $out"; fail=1; }

[ "$fail" = 0 ] && echo "Launcher parity: OK" || { echo "Launcher parity: FAILED - make the same change in both installers."; exit 1; }

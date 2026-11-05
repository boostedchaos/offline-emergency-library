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

for lite in 0 1; do
  sh_out="$T/sh-lite$lite/AI-Offline"; ps_out="$T/ps-lite$lite/AI-Offline"
  mkdir -p "$sh_out" "$ps_out"
  ( set +u; ROOT="$T/sh-lite$lite"; LITE=$lite; log(){ :; }; . "$T/sec.sh" ) || { echo "FAIL: bash launcher section exited non-zero (lite=$lite)"; fail=1; }
  if [ "$lite" = 1 ]; then L='$true'; else L='$false'; fi
  pwsh -NoProfile -NonInteractive -Command "\$ErrorActionPreference='Stop'; \$Root='$T/ps-lite$lite'; \$Lite=$L; function Log(\$m){}; . '$T/sec.ps1'" \
    || { echo "FAIL: PowerShell launcher section exited non-zero (lite=$lite)"; fail=1; }
  # Set-Content ends a file with the OS newline: CRLF on Windows, LF here. Make the last
  # line end like it does on Windows; every other line comes from the CRLF source above.
  for b in "$ps_out"/*.bat; do [ -e "$b" ] && perl -0pi -e 's/(?<!\r)\n\z/\r\n/' "$b"; done

  ns=$(ls "$sh_out" | wc -l | tr -d ' '); np=$(ls "$ps_out" | wc -l | tr -d ' ')
  echo "== lite=$lite: bash wrote $ns launchers, PowerShell wrote $np"
  if [ "$ns" -lt 4 ] || [ "$np" -lt 4 ]; then echo "FAIL: too few launchers written (expected at least 4)"; fail=1; fi
  if diff -r "$sh_out" "$ps_out" > "$T/diff.txt"; then
    ls "$sh_out" | sed 's/^/  same: /'
  else
    echo "FAIL: the two installers write different launchers (lite=$lite):"; head -40 "$T/diff.txt"; fail=1
  fi
  # .bat must be CRLF on every line; .sh must have no CR at all.
  for b in "$sh_out"/*.bat; do [ -e "$b" ] && [ "$(grep -cE $'[^\r]$|^$' "$b")" != 0 ] && { echo "FAIL: $(basename "$b") has a line without CRLF"; fail=1; }; done
  for s in "$sh_out"/*.sh; do [ -e "$s" ] && grep -q $'\r' "$s" && { echo "FAIL: $(basename "$s") has CR line ends"; fail=1; }; done
done

[ "$fail" = 0 ] && echo "Launcher parity: OK" || { echo "Launcher parity: FAILED - make the same change in both installers."; exit 1; }

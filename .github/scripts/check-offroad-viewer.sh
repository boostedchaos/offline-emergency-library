#!/usr/bin/env bash
# Offline regression for the cross-platform OffRoad viewer (#107): the generated launcher
# must prepare and link the existing OBF folder, and start the bundled viewer with the
# Java 21 compatibility flag. A fake java records the arguments, so no GUI or network is used.
set -eu
cd "$(git rev-parse --show-toplevel)" || exit 1
tmp="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmp"' EXIT
fail=0
ok(){ printf 'PASS: %s\n' "$*"; }
bad(){ printf 'FAIL: %s\n' "$*"; fail=1; }

extract(){
  awk -v marker="$1" 'index($0,marker){go=1;next} go && $0=="EOS"{exit} go'
}

viewer="$tmp/Maps with spaces/MapViewer-Desktop"
maps="$tmp/Maps with spaces"
mkdir -p "$viewer/offroad" "$viewer/jre/bin" "$maps/obf"
extract 'cat > "$MVD/prepare-maps.sh"' < get-offline-library.sh > "$viewer/prepare-maps.sh"
extract 'cat > "$MVD/VIEW-MAPS-OFFLINE.sh"' < get-offline-library.sh > "$viewer/VIEW-MAPS-OFFLINE.sh"
printf '' > "$viewer/offroad/OffRoad.jar"
cat > "$viewer/jre/bin/java" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CAPTURE"
EOF
chmod +x "$viewer/prepare-maps.sh" "$viewer/VIEW-MAPS-OFFLINE.sh" "$viewer/jre/bin/java"

if CAPTURE="$tmp/args" bash "$viewer/VIEW-MAPS-OFFLINE.sh" > "$tmp/launch.log" 2>&1; then
  ok "launcher exits successfully in a path with spaces"
else
  bad "launcher failed: $(tail -n 3 "$tmp/launch.log" | tr '\n' ' ')"
fi

[ -s "$tmp/args" ] && ok "fake Java was started" || bad "Java was not started"
[ -f "$viewer/offroad-home/.OffRoad/offroad.properties" ] && ok "first-run settings file exists" || bad "first-run settings file is missing"
grep -Fxq -- "-Duser.home=$viewer/offroad-home" "$tmp/args" && ok "OffRoad state is isolated under the viewer folder" || bad "user.home was not isolated"
grep -Fxq -- '-Dcom.sun.xml.bind.v2.bytecode.ClassTailor.noOptimize=true' "$tmp/args" && ok "Java 21 compatibility flag is present" || bad "Java 21 compatibility flag is missing"
grep -Fxq -- "$viewer/offroad/OffRoad.jar" "$tmp/args" && ok "the bundled OffRoad jar is launched" || bad "the OffRoad jar argument is missing"

link="$viewer/offroad-home/.OffRoad/maps"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    printf 'SKIP: native symlinks need extra privileges in Git Bash; CI runs this check on Linux\n'
    ;;
  *)
    [ -L "$link" ] && ok "OffRoad map folder is a link, not a second map copy" || bad "OffRoad map folder is not a link"
    [ "$(cd "$link" 2>/dev/null && pwd -P)" = "$(cd "$maps/obf" && pwd -P)" ] && ok "the link resolves to the prepared OBF folder" || bad "the link does not resolve to the OBF folder"
    ;;
esac

# Execute the installer-owned ARM64 package block with a local SQLite fixture. This
# protects the install payload, not a source string: Apple Silicon must receive the
# replacement under OffRoad manifest's original jar name, while other targets keep it.
awk 'index($0,"        if [ \"$PLAT\" = mac ] && [ \"$JARCH\" = aarch64 ]; then"){go=1} go{print} go && $0=="        fi"{exit}' \
  get-offline-library.sh > "$tmp/arm64-package.sh"
[ -s "$tmp/arm64-package.sh" ] && ok "Apple Silicon package block found" || bad "Apple Silicon package block is missing"
printf 'NEW-SQLITE\n' > "$tmp/sqlite-fixture.jar"
for arch in aarch64 x64; do
  pkg="$tmp/package-$arch"
  mkdir -p "$pkg/offroad.new/lib"
  printf 'ORIGINAL-SQLITE\n' > "$pkg/offroad.new/lib/sqlite-jdbc-3.30.1.jar"
  (
    MVD="$pkg"
    PLAT=mac
    JARCH="$arch"
    SQLITE_FIXTURE="$tmp/sqlite-fixture.jar"
    log(){ :; }
    fetch_sized(){ cp "$SQLITE_FIXTURE" "$2"; }
    . "$tmp/arm64-package.sh"
  )
  if [ "$arch" = aarch64 ]; then
    [ "$(cat "$pkg/offroad.new/lib/sqlite-jdbc-3.30.1.jar")" = 'NEW-SQLITE' ] && ok "Apple Silicon installs ARM64-compatible SQLite under the manifest name" || bad "Apple Silicon kept the incompatible SQLite jar"
  else
    [ "$(cat "$pkg/offroad.new/lib/sqlite-jdbc-3.30.1.jar")" = 'ORIGINAL-SQLITE' ] && ok "non-ARM OffRoad package keeps its original SQLite jar" || bad "non-ARM package was unexpectedly modified"
  fi
done

grep -Fq 'OffRoad-bin-0.6-beta2.zip' get-offline-library.sh && ok "bash installer downloads OffRoad" || bad "bash installer has no OffRoad download"
grep -Fq 'OffRoad-bin-0.6-beta2.zip' Get-OfflineLibrary.ps1 && ok "PowerShell installer downloads OffRoad" || bad "PowerShell installer has no OffRoad download"
grep -Fq 'mklink /J' Get-OfflineLibrary.ps1 && ok "Windows launcher links instead of copying maps" || bad "Windows launcher has no junction"
grep -Fq 'ClassTailor.noOptimize' Get-OfflineLibrary.ps1 && ok "Windows launcher carries the Java 21 flag" || bad "Windows launcher lacks the Java 21 flag"
grep -Fq 'offroad/OffRoad.jar' get-offline-library.sh && grep -Fq 'offroad\OffRoad.jar' Get-OfflineLibrary.ps1 && ok "both launchers point at the extracted OffRoad jar" || bad "a launcher points at the wrong OffRoad path"
grep -Fq 'World_basemap_mini_2.obf.zip' get-offline-library.sh && grep -Fq 'World_basemap_mini_2.obf.zip' Get-OfflineLibrary.ps1 && ok "both installers include OffRoad's world basemap" || bad "world basemap download is missing from an installer"

# Legacy OsmAndMapCreator launcher (#108): the viewer loads its map fonts from ./fonts, so the
# launcher must start it in app/ whatever folder the user runs it from. A fake
# OsmAndMapCreator.sh records the folder it was started in. prepare-maps.sh also prints the
# obf path, so the folder check matches the launcher's own Offline Rendering line.
extract 'cat > "$MVD/VIEW-MAPS-ON-PC.sh"' < get-offline-library.sh > "$viewer/VIEW-MAPS-ON-PC.sh"
mkdir -p "$viewer/app/fonts"
cat > "$viewer/app/OsmAndMapCreator.sh" <<'EOF'
#!/usr/bin/env bash
pwd -P > "$CAPTURE"
if [ -d fonts ]; then echo fonts-visible >> "$CAPTURE"; fi
EOF
chmod +x "$viewer/VIEW-MAPS-ON-PC.sh" "$viewer/app/OsmAndMapCreator.sh"
rm -f "$tmp/mc-start"
if (cd "$tmp" && CAPTURE="$tmp/mc-start" bash "$viewer/VIEW-MAPS-ON-PC.sh" > "$tmp/mc.log" 2>&1); then
  ok "legacy viewer launcher exits successfully"
else
  bad "legacy viewer launcher failed: $(tail -n 3 "$tmp/mc.log" | tr '\n' ' ')"
fi
[ "$(head -n 1 "$tmp/mc-start" 2>/dev/null)" = "$(cd "$viewer/app" && pwd -P)" ] && grep -Fxq fonts-visible "$tmp/mc-start" \
  && ok "legacy viewer starts in app/, where its fonts are" || bad "legacy viewer does not start in app/ (offline map has no street names, #108)"
grep -Fq "files' to $(cd "$maps" && pwd)/obf and click OK" "$tmp/mc.log" && ok "legacy viewer launcher prints the map folder for Offline Rendering" || bad "legacy viewer launcher does not print the obf folder"

# Optional viewer downloads (#272): fetch exits on a failed download, so every soft call must
# run in ( ... ), or a 404 / outage of an optional viewer stops the whole install at step 8b.
# Static: no soft call outside a subshell. Behavior: the installer's real fetch + fetch_sized
# with a curl that always fails; the run must go on after the soft call.
unsub="$(grep -n 'fetch_sized .* soft' get-offline-library.sh | grep -v '( fetch_sized ' || true)"
[ -z "$unsub" ] && ok "every soft fetch_sized call runs in a subshell" || bad "soft fetch_sized call outside ( ... ) stops the install on a failed download: $unsub"
fx="$tmp/fetchfx"; mkdir -p "$fx/bin"
printf '#!/bin/sh\nexit 22\n' > "$fx/bin/curl"; chmod +x "$fx/bin/curl"
{ echo 'log(){ printf "%s\n" "$*"; }'; echo 'USE_ARIA=0; DL_TTY=0'
  awk '/^fetch\(\)\{/{go=1} go{print} go&&/^\}/{exit}' get-offline-library.sh
  awk '/^remote_size\(\)\{/{print; exit}' get-offline-library.sh
  awk '/^fetch_sized\(\)\{/{go=1} go{print} go&&/^\}/{exit}' get-offline-library.sh
  echo 'if ( fetch_sized "https://example.invalid/x.zip" "$1/x.zip" "$(remote_size https://example.invalid/x.zip)" soft ); then echo GOT; else echo SKIPPED; fi'
  echo 'echo AFTER'
} > "$fx/run.sh"
PATH="$fx/bin:$PATH" bash "$fx/run.sh" "$fx" > "$fx/out.txt" 2>&1 || true
grep -Fxq SKIPPED "$fx/out.txt" && grep -Fxq AFTER "$fx/out.txt" && [ ! -e "$fx/x.zip" ] \
  && ok "a failed optional download is skipped and the run goes on" || bad "a failed optional download did not leave the run going: $(tr '\n' ' ' < "$fx/out.txt")"
# control: the same call without ( ... ) must end the run, or the check above proves nothing
sed 's/^if ( fetch_sized \(.*\) soft ); then/if fetch_sized \1 soft; then/' "$fx/run.sh" > "$fx/run-bare.sh"
grep -q '^if fetch_sized ' "$fx/run-bare.sh" || bad "control script was not made"
PATH="$fx/bin:$PATH" bash "$fx/run-bare.sh" "$fx" > "$fx/out-bare.txt" 2>&1 || true
grep -Fxq AFTER "$fx/out-bare.txt" && bad "control: a bare soft call did not stop the run, so the subshell check is not testing fetch's exit" || ok "control: a bare soft call stops the run (why the subshell is needed)"

# Ctrl+C during an aria2 download (#272): aria2 catches SIGINT and exits 7, so bash does not
# see the signal. fetch must re-raise it, or Ctrl+C in an optional ( ... ) download only skips
# that file and the install goes on. A fake aria2c that exits 7 on SIGINT; SIGINT goes to the
# whole process group, as a terminal Ctrl+C does.
if command -v perl > /dev/null 2>&1; then
  ax="$tmp/ariafx"; mkdir -p "$ax/bin"
  printf '#!/usr/bin/env bash\ntrap "exit 7" INT\necho started > "$FLAG"\nfor i in $(seq 1 100); do sleep 0.1; done\nexit 0\n' > "$ax/bin/aria2c"
  printf '#!/bin/sh\nexit 22\n' > "$ax/bin/curl"; chmod +x "$ax/bin/aria2c" "$ax/bin/curl"
  sed 's/^USE_ARIA=0; DL_TTY=0$/USE_ARIA=1; DL_TTY=0/' "$fx/run.sh" > "$ax/run.sh"
  grep -q '^USE_ARIA=1; DL_TTY=0$' "$ax/run.sh" || bad "aria2 Ctrl+C test script was not made"
  FLAG="$ax/flag" PATH="$ax/bin:$PATH" perl -e '$SIG{INT}="DEFAULT"; setpgrp(0,0); exec @ARGV' bash "$ax/run.sh" "$ax" > "$ax/out.txt" 2>&1 &
  apid=$!
  for i in $(seq 1 50); do [ -f "$ax/flag" ] && break; sleep 0.1; done
  if [ -f "$ax/flag" ]; then
    kill -INT -- "-$apid" 2>/dev/null; arc=0; wait "$apid" || arc=$?
    if grep -Fxq AFTER "$ax/out.txt"; then bad "Ctrl+C during an aria2 download in ( ... ) did not stop the run (exit $arc)"
    else ok "Ctrl+C during an aria2 download stops the run, also inside ( ... ) (exit $arc)"; fi
  else
    kill -- "-$apid" 2>/dev/null; wait "$apid" 2>/dev/null; bad "fake aria2c did not start"
  fi
else
  echo "SKIP: aria2 Ctrl+C test (no perl to start a process group)"
fi

if [ "$fail" -ne 0 ]; then
  echo "OffRoad viewer checks failed."
  exit 1
fi
echo "OffRoad viewer checks passed."

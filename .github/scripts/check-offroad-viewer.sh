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

if [ "$fail" -ne 0 ]; then
  echo "OffRoad viewer checks failed."
  exit 1
fi
echo "OffRoad viewer checks passed."

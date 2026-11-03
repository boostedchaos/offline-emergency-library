#!/usr/bin/env bash
# CHECK-DRIVE - checks that every file on this drive is still exactly as it was downloaded.
# It reads CHECKSUMS-SHA256.txt (written by the installer) and prints only the problems.
# macOS: double-click CHECK-DRIVE.command.  Linux: bash CHECK-DRIVE.sh
# Manual equivalent:  sha256sum -c --quiet CHECKSUMS-SHA256.txt   (macOS: shasum -a 256 -c -q ...)
cd "$(dirname "$0")" || exit 1
pause(){ [ -t 0 ] && read -r -p "Press Enter to close. " _; }
L=CHECKSUMS-SHA256.txt
if [ ! -f "$L" ]; then echo "$L is missing - cannot check. Re-run the installer to create it."; pause; exit 1; fi
n=$(grep -c . "$L")
echo "Checking $n files. On a large drive this can take 10 to 60 minutes. Only problems are printed."
if command -v sha256sum >/dev/null 2>&1; then sha256sum -c --quiet "$L"; rc=$?
else shasum -a 256 -c -q "$L"; rc=$?; fi
echo
if [ "$rc" = 0 ]; then echo "RESULT: ALL $n FILES OK."
else echo "RESULT: PROBLEM. The files listed above are damaged or missing. Delete each one and re-run the installer to download it again, or copy it from your second drive."; fi
pause
exit "$rc"

#!/bin/bash
# CHECK-DRIVE - proves every file on this drive is still exactly as it was downloaded.
# Run it once a year (macOS: double-click CHECK-DRIVE.command; Linux: bash CHECK-DRIVE.sh).
cd "$(dirname "$0")" || exit 1
if [ ! -f SHA256SUMS.txt ]; then echo "SHA256SUMS.txt is missing - cannot check."; read -r -p "Press Enter to close. " _; exit 1; fi
n=$(wc -l < SHA256SUMS.txt | tr -d ' ')
echo "Checking $n files. This can take 10 to 40 minutes. Only problems are printed."
if command -v sha256sum >/dev/null 2>&1; then sha256sum -c --quiet SHA256SUMS.txt; rc=$?
else shasum -a 256 -c -q SHA256SUMS.txt; rc=$?; fi
echo
if [ "$rc" = 0 ]; then echo "RESULT: ALL $n FILES OK."
else echo "RESULT: PROBLEM. The files listed above are damaged or missing. Re-download them, or use your second copy."; fi
read -r -p "Press Enter to close. " _
exit "$rc"

#!/bin/bash
# install.command - macOS double-click starter for the Offline Emergency Library.
# The macOS twin of install.bat: runs get-offline-library.sh from this folder if it is
# here, otherwise downloads it from GitHub first. Finder opens it in Terminal.
cd "$(dirname "$0")" || exit 1
pause(){ [ -t 0 ] && read -r -p "Press Return to close. " _; }
echo "================================================================"
echo "  OFFLINE EMERGENCY LIBRARY - INSTALLER"
echo ""
echo "  This downloads a complete offline survival library + AI:"
echo "  local AI chat, document Q&A, Wikipedia, US maps, and"
echo "  survival/repair/medical manuals."
echo ""
echo "  You will be asked ONE question: where to save the files."
echo "  (Tip: an external drive or USB with 128 GB+ free is ideal.)"
echo "================================================================"
echo ""
if [ -f ./get-offline-library.sh ]; then
  bash ./get-offline-library.sh; rc=$?
else
  echo "Downloading the installer script..."
  if tmp="$(mktemp -d)" && curl -fLsS -o "$tmp/get-offline-library.sh" "https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/get-offline-library.sh"; then
    bash "$tmp/get-offline-library.sh"; rc=$?
  else
    rc=1
  fi
fi
echo ""
if [ "$rc" = 0 ]; then
  echo "Done. Open START-HERE.html in the folder you chose."
else
  echo "Installation failed. Review the error above and _download.log, then re-run to resume."
fi
pause
exit "$rc"

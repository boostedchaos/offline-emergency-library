#!/bin/bash
# install.sh - Linux starter for the Offline Emergency Library.
# The Linux twin of install.bat / install.command: runs get-offline-library.sh from this
# folder if it is here, otherwise downloads it from GitHub first. Run it from a terminal:
#   bash install.sh
# Offers the point-and-click picker page (web/index.html) or a full install (#188).
cd "$(dirname "$0")" || exit 1
pause(){ [ -t 0 ] && read -r -p "Press Return to close. " _; }
echo "================================================================"
echo "  OFFLINE EMERGENCY LIBRARY - INSTALLER"
echo ""
echo "  This downloads a complete offline survival library + AI:"
echo "  local AI chat, document Q&A, Wikipedia, US maps, and"
echo "  survival/repair/medical manuals."
echo "================================================================"
echo ""

run_installer(){  # all args forwarded to the installer
  if [ -f ./get-offline-library.sh ]; then
    bash ./get-offline-library.sh "$@"; return $?
  fi
  echo "Downloading the installer script..."
  local tmp
  if tmp="$(mktemp -d)" && curl -fLsS -o "$tmp/get-offline-library.sh" "https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/get-offline-library.sh"; then
    bash "$tmp/get-offline-library.sh" "$@"; return $?
  fi
  return 1
}

open_page(){ xdg-open "$1" 2>/dev/null || sensible-browser "$1" 2>/dev/null || return 1; }

pick_and_install(){
  local page="./web/index.html"
  if [ ! -f "$page" ]; then
    echo "The picker page (web/index.html) is not in this folder."
    echo "Falling back to a full install."
    return 2
  fi
  echo "Opening the picker page in your browser..."
  open_page "$page" || echo "Could not open it automatically; open $page by hand."
  echo ""
  echo "In the page: tick what you want, then click \"Download selection.json\""
  echo "(it saves to your Downloads folder). When you have done that, come back here."
  read -r -p "Press Return once selection.json is in your Downloads... " _
  local sel
  sel="$(ls -t "$HOME/Downloads"/selection*.json 2>/dev/null | head -1)"
  if [ -z "$sel" ]; then
    echo "No selection*.json found in $HOME/Downloads. Falling back to a full install."
    return 2
  fi
  echo ""
  echo "Using: $sel"
  echo "----------------------------------------------------------------"
  run_installer --select "$sel" --check-selection || { echo "That selection file is not valid. Fix it in the page and try again."; return 1; }
  echo "----------------------------------------------------------------"
  printf "Install this selection? [y/N] "
  local ans; read -r ans
  case "$ans" in
    y|Y|yes|YES) run_installer --select "$sel"; return $? ;;
    *) echo "Cancelled. Nothing was downloaded."; return 3 ;;
  esac
}

echo "How would you like to install?"
echo "  [P] Pick what to install (opens a page in your browser)"
echo "  [A] Install with a few questions (where to save, how much, which maps) - default"
echo ""
printf "Choose P or A [A]: "
read -r choice
case "$choice" in
  p|P)
    pick_and_install; rc=$?
    if [ "$rc" = 2 ]; then
      # pick_and_install could not proceed (no picker page, or no selection file in Downloads).
      # The user asked to pick, so do not silently start a full (large) install - ask first.
      printf "Install everything instead? [y/N] "
      read -r ans
      case "$ans" in
        y|Y|yes|YES) run_installer; rc=$? ;;
        *) echo "Cancelled. Nothing was downloaded."; rc=3 ;;
      esac
    fi
    ;;
  *)
    run_installer; rc=$?
    ;;
esac

echo ""
if [ "${rc:-1}" = 0 ]; then
  echo "Done. Open START-HERE.html in the OfflineLibrary folder inside the folder you chose."
elif [ "${rc:-1}" = 3 ]; then
  :
else
  echo "Installation failed or was stopped. Review any error above and _download.log, then re-run to resume."
fi
pause
exit "${rc:-1}"

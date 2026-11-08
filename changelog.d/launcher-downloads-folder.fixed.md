- **The picker launchers find a moved Downloads folder, and ask for the file when they cannot.**
  `install.bat` only looked in `%USERPROFILE%\Downloads`, so a Downloads folder moved with
  *Properties → Location* or Folder Redirection was missed. It now asks Windows for the real
  folder (`shell:Downloads`). `install.sh` uses `xdg-user-dir DOWNLOAD` (localized folders) when
  it is installed; `install.command` keeps `~/Downloads`. When no `selection*.json` is found,
  all three let you drag the file in or paste its path (quotes and Terminal backslash escapes are
  stripped); an empty answer keeps the old "Install everything instead?" question. Fixes item 1
  of #207. _[@boostedchaos](https://github.com/boostedchaos) - PR #TBD._

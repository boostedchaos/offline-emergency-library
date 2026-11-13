- **Manual Q&A reader loads again.** The reader page only allowed PDF links in 2 folders, so the
  books added in `Manuals/Food-Growing`, `Manuals/Metalworking` and `Manuals/Survival-Preparedness`
  stopped the page at load with "Cannot load the manuals: Invalid PDF source path". The page now
  allows the same 5 folders as the installers, and `check-doc-allowlist.sh` also checks the
  reader's list. Found in #159.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #268._

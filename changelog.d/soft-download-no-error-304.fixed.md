- **A skipped optional download no longer prints a fatal-looking ERROR line.** On macOS and
  Linux, when an optional download failed (the Emergency Childbirth page while gutenberg.org was
  down, its images, a map viewer or the world map), the installer printed `ERROR: download
  failed ... Re-run the installer to resume.` before the note saying it was skipped, though the
  run went on. It now prints the same line as the Windows installer, `download failed: ...
  (optional, skipped; re-run to try again)`. Required downloads still stop the run with ERROR,
  and Ctrl+C still stops it. Resolves #304.
  _[@shloksangwan](https://github.com/shloksangwan) - PR #308._

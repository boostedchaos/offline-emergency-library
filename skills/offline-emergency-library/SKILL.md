---
name: offline-emergency-library
description: >
  Download a complete offline, no-internet "emergency library" to a drive the user
  chooses: an offline AI (two chat models + engines for every OS, with a browser chat that
  reads PDFs), full Wikipedia (Kiwix ZIM), offline US maps (OsmAnd), 60 Kiwix archives
  (medicine, survival, DIY/repair, food & garden, education, computing),
  public-domain US Army field manuals + medical PDFs, the Kiwix reader, launchers, and
  full documentation (Markdown + HTML). Invoke for requests like "download the offline
  emergency library", "/offline-emergency-library", "set up my offline survival kit",
  "get the offline AI + Wikipedia + maps + manuals". The ONLY thing to ask the user is
  where to save the files.
---

# Offline Emergency Library — one-shot downloader

When this skill is invoked, your job is simple:

1. **Ask exactly one question:** *"Where would you like to save these files?"*
   (e.g. a drive letter like `E:\`, or a folder path, or a USB/external drive path.)
   Do **not** ask anything else — no component menus, no confirmations.
2. **Run the downloader for the user's OS** with that path.
   - **Windows** (from the repo root):
     ```powershell
     ./Get-OfflineLibrary.ps1 -Destination "<the path the user gave>"
     ```
     Or standalone:
     ```powershell
     $s = Join-Path $env:TEMP 'Get-OfflineLibrary.ps1'
     curl.exe -sL https://raw.githubusercontent.com/boostedchaos/offline-emergency-library/main/Get-OfflineLibrary.ps1 -o $s
     powershell -NoProfile -ExecutionPolicy Bypass -File $s -Destination "<path>"
     ```
   - **macOS / Linux**:
     ```bash
     ./get-offline-library.sh -d "<the path the user gave>"
     # or standalone:
     curl -fsSL https://raw.githubusercontent.com/boostedchaos/offline-emergency-library/main/get-offline-library.sh | bash -s -- -d "<path>"
     ```
3. The script creates `<path>\OfflineLibrary\`, downloads everything (resumable), writes
   the launcher `.bat` files, and generates all docs as Markdown **and** HTML. It logs to
   `<path>\OfflineLibrary\_download.log`.
4. When it finishes, tell the user to open **`START-HERE.html`** in the destination.

## Notes for the assistant
- The default library is **about 168 GB** (243 GB with `--wikipedia maxi`) and takes
  several hours. It is **resumable** — if interrupted, run the same command again.
- When it finishes it prints any failures and exits non-zero. Report those to the user;
  do not say it succeeded unless the log ends with `DONE. Everything downloaded and checked.`
- The script auto-resolves the **latest** versions (llama.cpp engine, Kiwix reader
  and the ZIM archives) so it keeps working over time.
- Platform: **Windows** (PowerShell + curl, built in) or **macOS / Linux** (bash + curl +
  tar, built in; `unzip` enables the desktop map viewer). Pick the installer matching the
  user's OS.
- Every item is downloaded from its publisher onto the user's drive. Kiwix archives keep
  their own (mostly Creative Commons) licences; Hesperian's books are for personal use.
- If the user is low on disk space, you *may* mention the optional flags
  `--wikipedia nopic|mini|none`, `--skip-groups`, `--skip-maps`, `--skip-models`,
  `--skip-ai` (Windows: `-Wikipedia`, `-SkipGroups`, `-SkipMaps`, `-SkipModels`, `-SkipAI`)
  — but do not prompt for them unless asked. `--dry-run` / `-DryRun` shows the total size.

See `README.md` for the full contents list, storage/hardware requirements, and how to
use each component after downloading.

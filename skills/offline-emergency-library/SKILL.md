---
name: offline-emergency-library
description: >
  Download a complete offline, no-internet "emergency library" to a drive the user
  chooses: an offline AI (chat models + CPU/GPU engine), an offline document-Q&A app
  (GPT4All), full Wikipedia article text, offline maps (OsmAnd; default US, any
  country/region/continent selectable), survival/repair/
  medical archives (Kiwix ZIM: iFixit, Appropedia, WikiMed, survival/water/food/knots),
  public-domain US Army field manuals + medical PDFs, the Kiwix reader, launchers, and
  full documentation (Markdown + HTML), plus optional Khan Academy courses (opt-in).
  Invoke for requests like "download the offline
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
     curl.exe -sL https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/Get-OfflineLibrary.ps1 -o $s
     powershell -NoProfile -ExecutionPolicy Bypass -File $s -Destination "<path>"
     ```
   - **macOS / Linux**:
     ```bash
     ./get-offline-library.sh -d "<the path the user gave>"
     # or standalone:
     curl -fsSL https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/get-offline-library.sh | bash -s -- -d "<path>"
     ```
3. The script creates `<path>\OfflineLibrary\`, downloads everything (resumable), writes
   the launcher `.bat` files, and generates all docs as Markdown **and** HTML. It logs to
   `<path>\OfflineLibrary\_download.log`.
4. When it finishes, tell the user to open **`START-HERE.html`** in the destination.

## Notes for the assistant
- The full library is **~60 GB** and can take hours depending on the connection. It is
  **resumable** — if interrupted, just run the same command again.
- The script auto-resolves the **latest** versions (llama.cpp engine, Kiwix reader,
  GPT4All, and the ZIM archives) so it keeps working over time.
- Platform: **Windows** (PowerShell + curl, built in) or **macOS / Linux** (bash + curl +
  tar, built in; `unzip` enables the desktop map viewer). Pick the installer matching the
  user's OS.
- Everything downloaded is **free and legally redistributable**: open-weight AI models,
  openly-licensed Kiwix archives, and public-domain US-government manuals. No piracy.
- If the user is low on disk space, you *may* mention the optional flags
  `-SkipWikipedia`, `-SkipMaps`, `-SkipModels` — but do not prompt for them unless asked.
- **Education is opt-in.** Two choices, both off by default:
  `-Education` / `--education` adds the **Khan Academy** archive (Kiwix ZIM, ~168 GB, all
  videos; `-EduLang`/`--edu-lang` en|es|fr). `-Kolibri` / `--kolibri` adds the **Kolibri**
  learning app, where the user picks subjects + video quality in-app (tens of GB). Only add
  either if the user asks for courses/education.
- **Browser maps are opt-in.** `-BrowserMaps` / `--browser-maps` adds US street maps that open in
  any web browser (`Maps-Browser\OPEN-MAPS`; ~16.5 GB for all states, follows `-Region`). Offer it
  whenever the user asks for maps on a computer: on Windows and macOS the bundled desktop viewer
  (OsmAndMapCreator) needs internet — it draws online tiles, not the drive's maps — so browser maps
  are the only offline computer viewer there (US only). It adds to the OsmAnd maps (~17.8 GB for the
  US), so a full US drive needs about 34 GB for maps. For a non-US region on a computer, the only
  offline path is still the Android app.
- **Extra archives are opt-in.** `-ExtraZims` / `--extra-zims` adds the **Wikivoyage** travel
  guide and **Wikibooks** open textbooks (Kiwix ZIM, ~5.8 GB, CC BY-SA) in `Extra-Archives\`. Only
  add it if the user asks for travel guides or textbooks.
- **The translator is opt-in.** `-Translate` / `--translate` adds a two-way offline text
  translator (`AI-Offline\TRANSLATE.bat` / `translate.sh`; Qwen3 4B model, ~2.5 GB, Apache 2.0)
  that runs on the bundled AI engine. Only add it if the user asks for translation or for
  talking with people who speak another language.
- **MedlinePlus health topics are opt-in.** `-MedlinePlus` / `--medlineplus` adds the public-domain
  MedlinePlus health topic summaries (English + Spanish, ~30 MB) as one searchable browser page,
  `Medical\MedlinePlus\MedlinePlus-Health-Topics.html`. Only add it if the user asks for a
  plain-language health or symptom reference.
- **Maps default to the US.** If the user wants another area, pass `-Region <name>`
  (Windows) / `--region <name>` (macOS/Linux) — e.g. `France`, `"Germany,Austria"`,
  `Europe`, `US_texas`, or `world`. To discover exact names, run with `-ListRegions` /
  `--list-regions [filter]` (lists regions and exits, no download). Still ask only where
  to save unless the user brings up maps/region themselves.

See `README.md` for the full contents list, storage/hardware requirements, and how to
use each component after downloading.

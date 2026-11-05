# Changelog

All notable changes to this project are documented here. Dates are UTC.

This project is built and maintained in the open. Several fixes were found and
reported (or independently patched) by contributors running the installer on real
hardware — they are credited by name below. Thank you.

## [Unreleased]

Contributor-driven reliability and portability work, from people running the kit on real
hardware.

### Added
- **README: resale note.** The License section now says a drive made with this kit cannot be
  sold (giving copies away is fine) and names the non-commercial content: iFixit, the
  *Prolonged Casualty Care* guide, the WHO childbirth references, the two Hesperian books and
  the opt-in Khan Academy archive. Resolves #70. _[@EnragedAntelope](https://github.com/EnragedAntelope) - PR #89._
- **Self-check verifies the AI models.** Both installers now compare every `.gguf` model on
  the drive with the size and SHA-256 that Hugging Face publishes, so a cut-off or damaged
  model download ends the run with FINISHED WITH PROBLEMS and names the file, instead of
  failing later when someone tries to chat. The hash is taken from `CHECKSUMS-SHA256.txt`, so
  the models are not read twice; an unfinished aria2 download also fails, and no answer from
  Hugging Face is only a warning. Resolves #71. _[@EnragedAntelope](https://github.com/EnragedAntelope) - PR #88._
- **WHO childbirth and maternal-health references.** Both installers now download two WHO
  PDFs from `iris.who.int` into `Medical/Manuals-PDF/` (~9 MB), each checked to start with
  `%PDF`: *Managing complications in pregnancy and childbirth* (2nd ed., 2017) and *WHO
  recommendations on maternal health* (2nd ed., 2025). Both are CC BY-NC-SA 3.0 IGO (not
  public domain); `Medical/READ-ME-FIRST` gains a childbirth section with citations, license
  and redistribution terms, a "get skilled help first" warning, and an edition caution (WHO
  says several 2017 recommendations have since been updated). The source URLs are added to
  the link check. Resolves #24.
- **Psychological first aid guide.** A new `PSYCHOLOGICAL-FIRST-AID` guide (Markdown + offline
  HTML) in `Medical/`, placed by both installers and linked from `Medical/READ-ME-FIRST`, the
  "I need to…" index and the README. Plain-language, original-wording support for helping
  people — and helpers themselves — cope with fear, panic, grief and acute stress over the
  days and weeks of a crisis (the widely taught Look / Listen / Link approach, children, grief,
  helper self-care, and when to escalate). Written in our own words and citing the WHO PFA
  field guide and the bundled medical references as further reading; **no copyrighted text is
  reproduced or bundled** (the WHO guide is "all rights reserved", so it is linked, not
  shipped). Resolves #25.
- **Printable "emergency essentials" one-pager.** A new `EMERGENCY-ESSENTIALS` page (Markdown
  + print-optimized HTML) placed at the drive root by both installers and linked from
  START-HERE and the "I need to…" index. Paper is the only thing that works with a dead
  battery, so this is one page of the most critical reminders — severe bleeding, hands-only
  CPR, choking, making water safe (rolling boil 1 min / 3 min above ~2,000 m), signalling for
  help, and the key emergency frequencies (NOAA, marine VHF 16, aviation 121.5, 406 MHz
  beacon) — drawn from and citing the Army first-aid/survival manuals, *Where There Is No
  Doctor*, and the radio frequency reference already in the kit. Prints to ~2 pages via the
  browser (Ctrl+P); it is a reminder card, not a substitute for the manuals. Resolves #19.
- **Map and compass navigation guide.** A new `MAP-AND-COMPASS` guide (Markdown + offline
  HTML) covers reading a topo map, declination, taking and following a bearing, resection
  (triangulation) and natural direction finding (sun, shadow-stick, stars), adapted in
  original wording from public-domain U.S. Army manuals with sources listed. Linked from the
  maps guide and the "I need to..." index, listed in START-HERE and the README, and placed in
  `OsmAnd\` by both installers. Reinforces carrying a paper map and compass. Resolves #27.
  _[@EnragedAntelope](https://github.com/EnragedAntelope) - PR #47._
- **Prolonged-care medical guide.** Both installers now download *A Practical Guide to
  Prolonged Casualty Care* (Uniformed Services University + Henry M. Jackson Foundation, 2025;
  CC BY-NC-SA 4.0, not public domain) from `usuhs.edu` into `Medical/Manuals-PDF/` (~15 MB),
  checked to start with `%PDF`. `Medical/READ-ME-FIRST` names the license and marks it as an
  advanced reference, not a substitute for a clinician. Resolves #23.
  _[@boostedchaos](https://github.com/boostedchaos) — PR #45._
- **"I need to…" emergency quick index.** A new high-contrast `I-NEED-TO` page (Markdown +
  offline HTML) at the drive root, placed by both installers and linked prominently from the
  top of START-HERE. Unlike `README.html` (a catalog of everything), this is task-first: rows
  like *stop severe bleeding*, *do CPR*, *make water safe*, *call for help by radio* and
  *navigate without GPS* link straight to the exact file (the first-aid PDFs open on a click;
  ZIM archives say which one to open in Kiwix and what to search). It routes to the manual
  rather than giving the steps itself, works offline with no dependencies, and reads on a
  phone. Resolves #18.
- **Post-install self-check: no bare DONE on a broken kit.** After writing
  `CHECKSUMS-SHA256.txt`, both installers now run read-only checks of what was built and
  only print DONE if they pass — otherwise they end with `FINISHED WITH PROBLEMS`, name the
  failed check and exit 1. Checks: every engine folder has its `llama-cli` for all 8
  platforms; the engine for this computer actually starts (`--version`), with targeted hints
  for a missing VC++ runtime (Windows) or `libgomp.so.1` / too-old glibc (Linux); every
  `.zim` has the ZIM magic number and its full declared size; every `.pdf` starts with
  `%PDF`. Nothing is written to the drive. HOW-TO-RUN-OFFLINE-AI gains Linux troubleshooting
  for the two library errors the self-check surfaces. Resolves #30.
  _[@boostedchaos](https://github.com/boostedchaos) (Kyle Welch) — PR #43._
- **USDA Complete Guide to Home Canning.** Both installers now download the official
  2015 revision (Agriculture Information Bulletin 539, a US-government work) as its 8 PDF
  parts from the USDA-funded National Center for Home Food Preservation, into
  `Manuals/Food-Preservation/USDA-Complete-Guide-to-Home-Canning-2015/` (~14 MB), each checked to start with `%PDF`.
  Listed in the README and `Manuals/READ-ME-FIRST`. Resolves #22.
  _[@boostedchaos](https://github.com/boostedchaos) — PR #44._
- **Browser maps (opt-in): US street maps in any web browser.** New `-BrowserMaps` /
  `--browser-maps` (off by default) adds Project NOMAD / Protomaps PMTiles state maps, the
  MapLibre GL JS viewer and a bundled Caddy local web server, so streets open in any browser
  on Windows, macOS and Linux — no app and no Java. Follows `-Region` (US ≈16.5 GB for all
  states; a single state is far less), plus a low-detail world map. Fully attributed
  (maps MIT; data © OpenStreetMap contributors, ODbL; viewer BSD-3; Caddy Apache-2.0).
  Resolves #10/#38. _[@boostedchaos](https://github.com/boostedchaos) (Kyle Welch) — PR #38._
- **Printable radio frequency reference.** A new `RADIO-FREQUENCIES` guide (Markdown +
  offline HTML) with US frequency/channel tables (weather, FRS/GMRS/MURS/CB, marine,
  aviation, beacons, amateur band plans), regional cautions and primary sources
  (NOAA, FCC, USCG, FAA), linked from RADIO-GUIDE and the index. Also corrects the legal
  note in RADIO-GUIDE: 47 CFR §97.403/§97.405 are amateur-specific, not blanket permission
  for anyone to transmit on any frequency. Resolves #26.
  _[@EnragedAntelope](https://github.com/EnragedAntelope) — PR #40._
- **Lite map-size warning.** Because `--lite` still includes the default US maps (~17 GB),
  both installers now print the selected map region and the flags to pick a smaller area or
  skip maps entirely, before prompting for a destination or downloading. Resolves #32.
  _[@EnragedAntelope](https://github.com/EnragedAntelope) — PR #39._
- **Drive integrity: `CHECKSUMS-SHA256.txt` + CHECK-DRIVE.** At the end of every run both
  installers now write one SHA-256 per file to `CHECKSUMS-SHA256.txt` at the drive root —
  same format on every OS (`<sha256>  ./path`, byte-sorted, LF), so a drive built on Windows
  verifies on a Mac and back. Alongside it they place **CHECK-DRIVE** (double-click
  `CHECK-DRIVE.bat` on Windows / `CHECK-DRIVE.command` on macOS, `bash CHECK-DRIVE.sh` on
  Linux), which re-reads every file and prints only the damaged or missing ones, ending in
  `RESULT: ALL <n> FILES OK.` or a problem list. An unreadable file aborts the install
  (exit 1). README gained a "Keep it safe: two copies + CHECK-DRIVE" section and START-HERE
  links it. Resolves #28. _[@boostedchaos](https://github.com/boostedchaos) (Kyle Welch) — PR #36._
- **Live download progress.** Each file now shows a running transfer meter —
  percent with `curl`, and size/speed/ETA with `aria2` — so a long multi-GB run is
  no longer silent between "start" and "done". The meter appears only in an
  interactive terminal; with no TTY (cron/CI/piped, or redirected output on Windows)
  downloads stay quiet so logs aren't filled with progress bars.
- **Off-grid power and device guide.** A new `POWER-AND-DEVICES` guide (Markdown +
  offline HTML) covering watt-hour budgeting, a worked daily reading budget, solar
  sizing, power banks, vehicle and hand-crank charging, and picking the lowest-power
  device for the job — with carbon-monoxide and battery-safety warnings, and every
  figure labelled as an illustrative assumption to re-measure on real hardware. Also
  documents reading ZIMs on a Raspberry Pi / Linux ARM via `kiwix-serve` in the
  browser. Linked from START-HERE and the README. Resolves #17.
  _[@EnragedAntelope](https://github.com/EnragedAntelope) — PR #33._
- **`-Lite` / `--lite` quick-start preset.** Gets you running fast with the 3B model, AI
  engines, medical/survival archives, PDF manuals, readers, phone apps and regional maps,
  skipping full Wikipedia, the 8B/7B models, GPT4All, iFixit and Appropedia. Not a fixed
  small bundle (maps still default to US ~17 GB — pick a sub-region or `--skip-maps`);
  re-run without the flag to expand in place. Resolves #4. _[@EnragedAntelope](https://github.com/EnragedAntelope) — PR #16._
- **Offline AI runs on any OS from one drive.** Both installers now fetch the llama.cpp
  engine for Windows, macOS and Linux (all from one matching build) and unpack real files
  instead of symlinks, so a drive built on one computer runs the AI on another — and it no
  longer breaks on exFAT, where symlinks fail. _[@boostedchaos](https://github.com/boostedchaos)
  (Kyle Welch) — PR #9._
- **Fuller iPhone/iPad phone guide** — plugging in the drive, reading `.zim` archives
  straight off it in Kiwix with no copy (device-tested on iPad), importing maps into OsmAnd,
  and what doesn't run on iOS. _[@boostedchaos](https://github.com/boostedchaos) — PR #12._
- **Extra Kiwix archives (opt-in): `-ExtraZims` / `--extra-zims`.** Both installers can add the
  English **Wikivoyage** travel guide (~1.1 GB) and **Wikibooks** open textbooks (~4.7 GB),
  full builds with images, into `Extra-Archives/`. Off by default; without the flag the log
  says it was not selected. Both are CC BY-SA 4.0 (Wikibooks is also GFDL). **WikiHow is not
  included:** download.kiwix.org no longer lists it (the newest copy is a 2023 archive build of
  ~51 GB), and wikiHow stopped licensing new user content under CC BY-NC-SA 3.0 on
  24 March 2025. The CI link check now covers the two new Kiwix folders.
- **Offline translator (opt-in): `-Translate` / `--translate`.** Both installers can add
  Qwen3-4B-Instruct-2507 (Q4_K_M, ~2.5 GB, Apache 2.0) and `AI-Offline/TRANSLATE.bat` /
  `translate.sh`, a two-way text translator for talking with someone who speaks another
  language. It runs on the bundled llama.cpp engine, so no Python or other runtime is added;
  it needs about 6 GB RAM. Off by default. The new `HOW-TO-TRANSLATE` guide covers the checks
  that catch mistakes and which languages worked in testing (weak for Swahili, Somali and
  Amharic). Resolves #21. _[@EnragedAntelope](https://github.com/EnragedAntelope) - PR #62._
- **MedlinePlus health topics (opt-in): `-MedlinePlus` / `--medlineplus`.** Both installers can
  add the MedlinePlus health topic summaries from the US National Library of Medicine (public
  domain), English and Spanish, as one searchable page that opens offline in any browser:
  `Medical/MedlinePlus/MedlinePlus-Health-Topics.html` (~30 MB). It is built from NLM's
  official XML file, not the Kiwix MedlinePlus ZIM, because the ZIM also contains the
  copyrighted A.D.A.M. encyclopedia and ASHP drug pages; those are not included. The page
  makes no network requests. Off by default. Resolves #64.
  _[@EnragedAntelope](https://github.com/EnragedAntelope) - PR #87._

### Changed
- **Lite no longer leaves the AI's trust gap silent.** `--lite` / `-Lite` still omits GPT4All
  (keeping the preset lean — forcing it back in would undo the #32/#39 sizing work), but a lite
  drive therefore has only the plain 3B chat with **no source-citing RAG** — the less
  trustworthy path #20 warns about. Rather than skip it silently, both installers now drop a
  `GPT4All-NOT-INCLUDED-IN-LITE.txt` note in `AI-Offline/DocReader-GPT4All/` explaining the
  limitation and how to add it, and the docs say so plainly: HOW-TO-RUN-OFFLINE-AI and
  HOW-TO-ASK-YOUR-DOCS gained a lite caveat ("treat answers as leads, verify against the
  manuals; re-run without the lite flag to add the citing LocalDocs workflow"), and the README
  lite section spells out the no-citation consequence. Resolves #31.
- **Manuals-first AI framing.** The guides now treat the bundled manuals as the authority and the AI as the assistant: START-HERE opens with how the kit is meant to be used, spells out the three ways to read and use things (fixing the GPT4All pointer to `AI-Offline\DocReader-GPT4All\`), and points safety-critical answers at the manual itself; HOW-TO-RUN-OFFLINE-AI gains a "How to use the AI well" note (GPT4All LocalDocs shows the sources it used, so medical and survival answers can be checked against the book). Every generated AI launcher now also prints a one-line reminder (the AI is a helper, follow the manuals for anything safety-critical) before the engine starts. Resolves #20. _[@EnragedAntelope](https://github.com/EnragedAntelope) - PR #42._
- **Browser maps: total map size stated.** HOW-TO-VIEW-MAPS, the README options table and the skill now say that browser maps come on top of the OsmAnd maps, so a full US drive with `-BrowserMaps` needs about 34 GB for maps (16.5 + 17.8 GB, measured on a real install). Suggested in #15. _[@EnragedAntelope](https://github.com/EnragedAntelope) - PR #58._

### Fixed
- **A re-run no longer keeps or corrupts downloads whose name stays the same.** OsmAnd maps,
  OsmAndMapCreator (nightly), the portable Java runtime and the browser-maps style archive
  keep their file name when the source publishes a new edition, so a re-run resumed the new
  edition into the old file (`curl -C -` / `aria2 -c`): a smaller old copy became a spliced,
  corrupt file, and a larger one was kept as "complete". Both installers now compare the
  file on disk with the source's size (OsmAnd's `containerSize` from `get_indexes` for maps,
  the server's `Content-Length` for the "latest" URLs). A file of the right size is kept;
  otherwise the new edition downloads to `<name>.<bytes>.part`, so a resume never mixes
  editions, and it replaces the old file only once it is complete and the right size. The
  desktop viewer and its Java runtime now unpack to a new folder and replace the working
  copy only if the unpack worked, so a bad archive no longer leaves a half-overwritten
  viewer. If a server gives no size, the download behaves as before. Resolves #57, the same
  class of bug as #35. _Reported by [@EnragedAntelope](https://github.com/EnragedAntelope) — issue #57._
- **Blank desktop map on Windows now has a working path.** The bundled OsmAndMapCreator
  viewer ships a Linux-only native renderer, so on some Windows PCs the window opens with a
  blank map. Rather than patch that Java build, the kit now steers Windows users to the
  cross-platform **browser maps** (added in #38) as the recommended computer viewer:
  HOW-TO-VIEW-MAPS leads with browser maps and reframes the OsmAndMapCreator viewer as the
  option for non-US regions / macOS / Linux; the Windows desktop launcher (`VIEW-MAPS-ON-PC.bat`)
  now prints what to do if the map is blank; and a Windows install that includes maps without
  `-BrowserMaps` prints a tip to add them. Browser maps are US-only, so non-US Windows users
  are pointed to the tested Android path. Addresses #15. _Reported by
  [@EnragedAntelope](https://github.com/EnragedAntelope) — issue #15._
  failure that left a `.aria2` control file), `fetch()` fell back to `curl -C -`; because
  aria2 preallocates the full file size, curl saw a "complete" file and kept it — a drive of
  gaps/metalink XML that passed the non-empty check and let the install finish silently. Both
  installers now stop with exit 1 on aria2 exit 7 or a leftover `.aria2` (aria2 resumes
  cleanly on re-run) and pass `--follow-metalink=mem` so Kiwix's metalink is never saved as
  the file. Found via the #34 testing. _[@boostedchaos](https://github.com/boostedchaos)
  (Kyle Welch) — PR #41._
- **Re-run on a newer llama.cpp build could corrupt the engine.** A resumed download appended
  the new build onto the old build's archive (and a damaged zip can unpack to nothing with no
  error on PowerShell 5.1), leaving zero working engines while the run still printed DONE.
  Archives are now saved per build (`<build>-<asset>`), stale builds removed, an unpack
  failure exits 1, and the installer verifies `llama-cli` is actually present after unpacking.
  Resolves #35. _[@boostedchaos](https://github.com/boostedchaos) (Kyle Welch) — PR #37._
- **Default `US` maps downloaded 0 files on macOS/Linux.** The Bash region loop fed `read`
  a list with no trailing newline, so it dropped the last (and, for `US`, only) region name.
  _[@boostedchaos](https://github.com/boostedchaos) — PR #11._
- **Offline AI chat was broken on current llama.cpp.** Recent `llama-cli` builds reject the
  obsolete `-cnv` flag (now scoped away from the CLI); conversation mode auto-activates for
  the bundled instruct models anyway, so the flag was removed from every launcher and the
  manual examples. _[@EnragedAntelope](https://github.com/EnragedAntelope) — PR #13._
- **Failed downloads were silently saved as real files.** The `curl` fallback lacked `-f`,
  so an HTTP 404/5xx body could be written as a `.gguf`/`.zim`/`.pdf` and the run continued
  to its success banner. Both installers now use `-fL`/`-sS` with exit-code and non-empty
  checks, route the medical PDFs through the checked helper, and `install.bat` propagates
  failure instead of always printing "Done". A failed or non-`%PDF` download now stops the
  run (re-runnable — payloads resume). _[@EnragedAntelope](https://github.com/EnragedAntelope)
  — PR #14._
- **Bash prompt skipped its friendly message with no terminal.** `[ -r /dev/tty ]` is true
  even when no controlling terminal exists (cron/CI/non-tty `ssh`), so the read errored
  instead of showing the "pass `-d`" hint. It now actually tests that the tty is openable.
  _Reported by [@boostedchaos](https://github.com/boostedchaos) (issue #1)._

### Known issues
- The bundled OsmAndMapCreator desktop viewer itself still renders a blank map on some Windows
  setups (Linux-only native renderer). The **browser maps** are now the recommended Windows
  computer viewer and render reliably (US maps); non-US Windows users use the Android path. See
  the "Blank desktop map on Windows" entry above. Tracking in issue #15 until re-tested.
  _Reported by [@EnragedAntelope](https://github.com/EnragedAntelope) — issue #15._

## [v1.4] — 2026-11-02 — faster downloads (aria2)

### Added
- **Optional aria2 acceleration.** If [`aria2`](https://aria2.github.io/) is
  installed, both installers use it automatically (16 parallel connections,
  resumable) for the big files — a real difference on the ~85 GB full build. Falls
  back to `curl` when aria2 isn't present, or force `curl` with `-NoAria` /
  `--no-aria`. _Idea courtesy of **[@boostedchaos](https://github.com/boostedchaos)**
  (Kyle Welch)._

## [v1.3] — 2026-11-02 — macOS/Linux reliability + region aliases

Reliability release, largely from field reports by contributors running the Bash
installer on macOS and Linux.

### Fixed
- **ZIM archives now download on macOS/Linux.** The directory-listing `curl` calls
  in the Bash installer were missing `-L`, so `download.kiwix.org`'s 301 redirect to
  `lb.download.kiwix.org` returned the redirect page, matched nothing, and every
  Kiwix archive silently came back "not found" (no iFixit, Appropedia, WikiMed,
  zimgit guides, or the Kiwix reader). Now every lookup follows redirects, matching
  the PowerShell installer. _Independently found and reported by
  **[@boostedchaos](https://github.com/boostedchaos)** (Kyle Welch) in a macOS test
  report, and by **[@xtalax](https://github.com/xtalax)** (Alex Jones) in a real
  Arch Linux run — PR #5._
- **`curl … | bash` now prompts correctly** for the save path. It was reading its
  own piped script text as the destination; it now reads from `/dev/tty`.
  _Reported and fixed by **[@boostedchaos](https://github.com/boostedchaos)**
  (Kyle Welch) — PR #7._
- **Wikipedia is now Kiwix-readable.** Ships the `wikipedia_en_all_nopic` ZIM
  (~49 GB) instead of a raw `.xml.bz2` dump that Kiwix can't open — matching what
  START-HERE and HOW-TO-ASK-YOUR-DOCS tell people to use. _Reported and fixed by
  **[@boostedchaos](https://github.com/boostedchaos)** (Kyle Welch) — PR #8._
- **Medical PDFs** — dropped borrow-only Internet Archive items that returned 401
  error pages; now uses freely-downloadable copies, with `-f` + `%PDF` validation so
  a bad download is never saved.
- **Garbled em-dashes** in some HTML guides fixed (UTF-8 handling).

### Added
- **Country / ISO region aliases** — `-Region` / `--region` accepts `UK`, `USA`,
  `GBR`, `DEU`, `FRA`, `JPN`, `UAE`, `Holland`, `Czech`, … and maps them to the
  correct OsmAnd region name.

## [v1.2] — 2026-11-02 — offline learning (opt-in)

### Added
- **`--education` / `-Education`** — adds the **Khan Academy** archive (Kiwix ZIM,
  ~168 GB incl. video). Language via `--edu-lang` / `-EduLang` (en/es/fr).
- **`--kolibri` / `-Kolibri`** — adds the **Kolibri** learning app so you can pick
  subjects and video quality and keep it to tens of GB. Bundles the
  Windows/macOS/Linux installers + Android APK and a `HOW-TO-KOLIBRI` guide.

Both are off by default; defaults are otherwise unchanged.

## [v1.1] — 2026-11-01 — map regions + root index

### Added
- **Choose your map region.** Maps default to the US, but you can pick any country,
  continent, sub-region, or the whole world
  (`-Region France` / `--region "Germany,Austria"` / `--region Europe` /
  `--region US_texas` / `--region world`).
- **Region discovery** — `-ListRegions` / `--list-regions [filter]` lists regions
  and exits (no download).
- **Size guardrail** — prints the resolved map size and warns before very large
  downloads.
- **Root index** — installers generate a clickable `README.html` at the download
  root, indexing every guide, document, manual, archive, app and data file.

### Fixed
- Exclude road-only map variants so region counts/sizes are correct.

## [v1.0] — 2026-11-01 — initial release

One command downloads a complete offline, no-internet emergency library. It asks
only where to save, then downloads everything and writes all docs (Markdown + HTML).
Includes offline AI chat (3 models + CPU/GPU engines), GPT4All document Q&A, full
Wikipedia article text, offline maps (OsmAnd) with a desktop viewer and bundled
Android app, survival/repair/medical archives via bundled Kiwix, public-domain Army
field manuals + medical PDFs, a radio communications guide, and phone apps.
Resumable; cross-platform (Windows / macOS / Linux). All content is free and legally
redistributable.

[v1.4]: https://github.com/elhajahmadj/offline-emergency-library/releases/tag/v1.4
[v1.3]: https://github.com/elhajahmadj/offline-emergency-library/releases/tag/v1.3
[v1.2]: https://github.com/elhajahmadj/offline-emergency-library/releases/tag/v1.2
[v1.1]: https://github.com/elhajahmadj/offline-emergency-library/releases/tag/v1.1
[v1.0]: https://github.com/elhajahmadj/offline-emergency-library/releases/tag/v1.0

# Changelog

All notable changes to this project are documented here. Dates are UTC.

This project is built and maintained in the open. Several fixes were found and
reported (or independently patched) by contributors running the installer on real
hardware — they are credited by name below. Thank you.

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

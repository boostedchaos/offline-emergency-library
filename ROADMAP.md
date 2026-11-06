# Roadmap

Ideas for where this is headed. Nothing here is promised — it's a place to coordinate.
Want one of these? Comment on (or open) the matching issue. PRs welcome.

## Near term
- [x] **`--lite` quick-start preset** — a ~2–3 GB "get running in minutes" build (3B AI +
      medical + survival + regional maps, no 24 GB Wikipedia). _Done: `-Lite` / `--lite` (see CHANGELOG)._
- [x] **Checksums on releases** — publish SHA-256 for the installers so people can verify
      before running. _Done: `SHA256SUMS.txt` is attached to each release since v1.1._
- [x] **Real-hardware testing** of the macOS and Linux installers (help wanted). _Done: macOS in #1, Linux x64 + Raspberry Pi arm64 in #2._
- [x] **Country-name aliases** — accept `UK`, `USA`, ISO-3 codes, etc. and map them to
      OsmAnd region names. _Done in v1.3._

## Phone experience
- [ ] **"Phone docs" pack** — a small bundle of the RAG-friendly PDFs + guides, importable
      into on-device document-AI apps (e.g. NomadAI), for iOS and Android.
      ([#79](https://github.com/elhajahmadj/offline-emergency-library/issues/79))
- [ ] QR code + one-tap download link for the phone pack.
      ([#79](https://github.com/elhajahmadj/offline-emergency-library/issues/79))

## Content
- [ ] More curated public-domain / openly-licensed manuals (gardening, water, comms).
      ([#78](https://github.com/elhajahmadj/offline-emergency-library/issues/78))
- [x] **Optional extra ZIM archives behind a flag** — Wikivoyage + Wikibooks (CC BY-SA),
      opt-in `-ExtraZims` / `--extra-zims`. _Done in #56. WikiHow was not added — it isn't on
      download.kiwix.org today._

## Platform / packaging
- [ ] **Front end for non-technical users** — a guided installer first (size presets, no
      flags to memorize), then a possible desktop app later. Direction and sub-issues in
      [#66](https://github.com/elhajahmadj/offline-emergency-library/issues/66)
      (guided install [#80](https://github.com/elhajahmadj/offline-emergency-library/issues/80)).
- [ ] Verify/handle upstream source changes automatically — cover every runtime in the CI
      link check ([#77](https://github.com/elhajahmadj/offline-emergency-library/issues/77))
      and drive it from one source-of-truth table
      ([#67](https://github.com/elhajahmadj/offline-emergency-library/issues/67)).

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) to get started.

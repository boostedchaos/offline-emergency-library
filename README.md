# 🛟 Offline Emergency Library

**An offline "survival knowledge" drive you can build with one command.** It holds
Wikipedia, medical and survival references, repair guides, maps, books and an offline AI.
After the download, everything works with **no internet**, on **any computer**
(Windows, macOS, Linux) and on Android phones.

The installer asks one question (where to save), then downloads, checks and indexes
everything. It is made for a drive you keep somewhere safe, such as a lockbox.

> **This is a fork** of [elhajahmadj/offline-emergency-library](https://github.com/elhajahmadj/offline-emergency-library).
> See [What this fork changed](#what-this-fork-changed) below.
>
> **Inspired by [Project NOMAD](https://github.com/Crosstalk-Solutions/project-nomad)**
> ([projectnomad.us](https://www.projectnomad.us)) by Crosstalk Solutions — a full
> offline knowledge server with AI, maps, Kiwix and Kolibri. Its curated content
> collections are the basis of this fork's archive list. If you want an always-on
> offline server instead of a drive in a drawer, use NOMAD. See [Credits](#credits).

---

## What you get

Sizes come from a full dry run on 2026-11-01 (`--dry-run --wikipedia maxi`). Kiwix
publishes new builds often, so sizes move a little over time. Run `--dry-run` for today's numbers.

| Part | What it is | Size |
|---|---|---|
| **Wikipedia** | All English articles, in Kiwix format. Pick the version with `--wikipedia`: `maxi` (with images), `nopic` (default, no images), `mini` (intro of each article), `none` | maxi 127.4 GB · nopic 52.7 GB · mini 14.4 GB |
| **Medicine** | Field and military medicine, CDC, NHS medicines A–Z, MedlinePlus, LibreTexts medicine, LibrePathology (+ WikiMed if you skip full Wikipedia) | 3.6 GB |
| **Survival** | Water, food, knots, post-disaster library, Ready.gov, outdoors and ham-radio Q&A, off-grid and appropriate-technology libraries, prepper video channels | 15.0 GB |
| **DIY & repair** | iFixit, Appropedia, home-improvement, woodworking and car-maintenance Q&A | 6.7 GB |
| **Food & garden** | Cooking sites, gardening and cooking Q&A, homesteading videos, Gutenberg agriculture books | 9.7 GB |
| **Education** | Wikibooks, Wikiversity, LibreTexts (math, physics, chemistry, biology, engineering, more), TED-Ed and TED talks | 44.7 GB |
| **Computing** | Python, JavaScript, Linux, Docker, Git docs; Arduino, Raspberry Pi, electronics Q&A | 5.1 GB |
| **Books (PDF)** | 11 public-domain US Army manuals + Hesperian's *Where There Is No Doctor* and *Where There Is No Dentist* | 0.2 GB |
| **Maps** | All 83 OsmAnd US map files + desktop map viewer + Android app | 17.9 GB |
| **Offline AI** | llama.cpp engine + 3 chat models (3B, 8B, 7B) + GPT4All | 11.9 GB |
| **Readers** | Kiwix readers for Windows, macOS (Intel + Apple) and Linux (x64 + ARM), Kiwix desktop app, Kiwix Android app | 0.8 GB |
| **Total** | with `--wikipedia maxi` / default `nopic` | **243 GB / about 168 GB** |

Choose a drive with room to spare: **256 GB** for the default, **500 GB** for
Wikipedia with images. An **external SSD** is much faster than a flash drive.

---

## 🚀 How to download

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/boostedchaos/offline-emergency-library/main/get-offline-library.sh | bash
```

Or clone and run with options:

```bash
git clone https://github.com/boostedchaos/offline-emergency-library.git
cd offline-emergency-library
./get-offline-library.sh --dry-run --wikipedia maxi          # check links + size first
./get-offline-library.sh -d /Volumes/MyDrive --wikipedia maxi
```

### Windows

Double-click **`install.bat`**, or paste this into PowerShell:

```powershell
$s="$env:TEMP\Get-OfflineLibrary.ps1"; curl.exe -sL https://raw.githubusercontent.com/boostedchaos/offline-emergency-library/main/Get-OfflineLibrary.ps1 -o $s; powershell -NoProfile -ExecutionPolicy Bypass -File $s
```

With options: `.\Get-OfflineLibrary.ps1 -Destination E:\ -Wikipedia maxi`

### Claude Code

Install the skill in `skills/offline-emergency-library/`, then say `/offline-emergency-library`.

### Options

| Mac/Linux | Windows | Effect |
|---|---|---|
| `--wikipedia maxi\|nopic\|mini\|none` | `-Wikipedia ...` | Which Wikipedia (default `nopic`) |
| `--skip-groups a,b` | `-SkipGroups a,b` | Skip groups: `medicine,survival,diy,food,education,computing,pdfs` |
| `--skip-maps` | `-SkipMaps` | No maps |
| `--skip-models` | `-SkipModels` | Only the small AI model |
| `--skip-ai` | `-SkipAI` | No AI at all |
| `--dry-run` | `-DryRun` | Check every link and add up the size. Downloads nothing |
| `--jobs N` | `-Jobs N` | Archives downloaded at the same time (default 4) |

**Resumable:** if it stops, run the same command again. It keeps finished files and
continues the rest. Run it again later to add newer builds.

**Speed — install aria2 first.** Kiwix's mirrors give about 3 MB/s per connection, so
one 127 GB Wikipedia file would take about 12 hours with plain curl. With
[aria2](https://aria2.github.io) the script downloads each archive in up to 16 pieces
from several Kiwix mirrors at once, and aria2 checks every 4 MB piece against Kiwix's
fingerprints. Measured on 2026-11-01 (2 Gbit line, exFAT SSD): **86–94 MB/s with aria2
vs 11 MB/s with curl**. Each run first times every mirror for a few seconds and skips the ones
slower than 1 MB/s (on 2026-11-01 `mirror.download.kiwix.org` gave 0.04–0.07 MB/s and stalled aria2).
- macOS: `brew install aria2` · Linux: `sudo apt install aria2`
- Windows: nothing to do — the script uses the `aria2c.exe` inside the Kiwix desktop app it downloads.

On an exFAT drive the first minutes of a big file are slow: exFAT has no sparse files, so
the OS writes zeros up to each piece aria2 starts far into the file. It speeds up once
that is done.

---

## 🧭 After it finishes

On the drive, in `OfflineLibrary/`:

| Open this | To do this |
|---|---|
| **`README.html`** | See a clickable index of everything on the drive |
| **`START-HERE.html`** | Read a guided intro |
| **`OPEN-LIBRARY`** (`.command` Mac, `.bat` Windows, `.sh` Linux) | Read every archive (Wikipedia, medical, survival…) in your web browser. Nothing to install |
| **`CHECK-DRIVE`** (`.command` / `.bat` / `.sh`) | Prove every file is still exactly as downloaded |

The script ends with a list of anything that failed and exits with an error, so a
partial download is never silent.

---

## 🔒 Keeping the drive in a lockbox

- **Format the drive as exFAT.** Windows, macOS, Linux and Android can all read it.
  (FAT32 cannot hold files over 4 GB; APFS and NTFS are not readable everywhere.)
- **Use a media-rated safe (UL Class 125).** A normal "Class 350" fire safe only keeps
  the inside under 350 °F, which can ruin a drive. Class 125 keeps it under 125 °F.
- **Plug it in once a year and run CHECK-DRIVE.** SSDs left without power slowly lose
  data. The JEDEC standard for consumer SSDs only promises 1 year without power for a
  worn drive at 30 °C; new drives usually last longer, but check.
- **Keep two copies** in two places. Re-run the installer on a spare drive each year to
  refresh content.
- **Practice now.** Open the library and the maps once, so you know how in an emergency.

---

## What this fork changed

Every item below was reproduced on 2026-11-01 before it was fixed.

- **Mac/Linux got 0 archives and 0 maps.** Kiwix listings redirect and the script did not
  follow redirects; OsmAnd renamed `US_` maps to `Us_`. Both fixed.
- **Wikipedia could not be read.** It was the raw 25.8 GB XML dump; Kiwix cannot open
  it. It is now a Kiwix archive.
- **Failed downloads were saved as files.** Two medical PDFs are borrow-only on
  archive.org (HTTP 401), and the error page was saved as `.pdf`. Downloads now fail on
  HTTP errors, check the size, resume, and are listed at the end.
- **Archives are checked** against the SHA-256 fingerprint Kiwix publishes; a damaged one
  is deleted and fetched again on the next run. `SHA256SUMS.txt` + `CHECK-DRIVE` cover the
  whole drive.
- **Any computer can read the drive:** readers for every platform are included, plus
  `OPEN-LIBRARY` launchers. Before, a Mac had no reader.
- **Much more content:** 60 archives in 6 groups (`catalog/zims.tsv`), adapted from
  [Project NOMAD](https://github.com/Crosstalk-Solutions/project-nomad)'s curated lists.
  The newest build is picked automatically, because Kiwix deletes old ones.
- **Faster:** archives use aria2 (many mirrors, many pieces) when it is installed;
  program files come from the first working Kiwix mirror (the default server
  gave 62 KB/s); archives download 4 at a time.
- `--dry-run`, one run per folder at a time, and `curl | bash` no longer eats its own input.
- The HTML guides are rebuilt from the Markdown (`tools/render-docs.sh`); the old ones
  showed garbled emoji and dashes.

---

## Credits

- **[Project NOMAD](https://github.com/Crosstalk-Solutions/project-nomad)** by
  [Crosstalk Solutions](https://www.projectnomad.us) — the inspiration for this fork. Its
  curated collections (`collections/kiwix-categories.json`, Apache-2.0) became
  `catalog/zims.tsv`: the medicine, survival, DIY, food & garden, education and computing
  groups, and the Wikipedia size options. NOMAD runs as a home server (Docker, web UI,
  local AI, maps, Khan Academy via Kolibri); this fork puts similar content on a single
  drive you can store offline. Thank you to the NOMAD team and community.
- **[elhajahmadj/offline-emergency-library](https://github.com/elhajahmadj/offline-emergency-library)** —
  the original one-command downloader, guides and folder layout.
- **[Kiwix](https://kiwix.org)** and its mirror hosts — the ZIM archives and readers.
- **[OsmAnd](https://osmand.net)**, **[llama.cpp](https://github.com/ggml-org/llama.cpp)**,
  **[GPT4All](https://github.com/nomic-ai/gpt4all)**, **[Hesperian](https://hesperian.org)**,
  and the US Army manuals on the [Internet Archive](https://archive.org).

## ⚠️ Disclaimers

- Offline AIs and older manuals **can be wrong or outdated**. Check anything
  safety-critical (medical, electrical, structural) against current sources when you can.
  This kit is reference material, **not** professional advice.
- **Licences.** The scripts download each item from its publisher onto your own drive.
  Kiwix archives keep their own licences (mostly Creative Commons). US Army manuals are
  US-government works. AI models keep their model licences. **Hesperian's books** are
  free to download for personal use, but Hesperian asks for permission before you share
  them digitally — so download your own copy, and do not redistribute the drive's
  Hesperian folder.
- Modern code books (NEC/UPC) and brand auto manuals are copyrighted and **not** included.
- Follow your local laws for radio transmission (listening is always fine).

## License

Code and documentation in this repo: **MIT** (see `LICENSE`). `catalog/zims.tsv` is
adapted from Project NOMAD's `collections/kiwix-categories.json` (Apache-2.0); see `NOTICE`.

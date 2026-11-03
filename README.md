# 🛟 Offline Emergency Library

[![Stars](https://img.shields.io/github/stars/elhajahmadj/offline-emergency-library?style=flat)](https://github.com/elhajahmadj/offline-emergency-library/stargazers)
[![Forks](https://img.shields.io/github/forks/elhajahmadj/offline-emergency-library?style=flat)](https://github.com/elhajahmadj/offline-emergency-library/network/members)
[![Latest release](https://img.shields.io/github/v/release/elhajahmadj/offline-emergency-library)](https://github.com/elhajahmadj/offline-emergency-library/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/elhajahmadj/offline-emergency-library/ci.yml?label=CI)](https://github.com/elhajahmadj/offline-emergency-library/actions)
[![License: MIT](https://img.shields.io/github/license/elhajahmadj/offline-emergency-library)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20Linux-informational)

**A complete, offline, no-internet "survival knowledge" kit you can download with a single
command.** Built for emergencies, grid-down scenarios, remote areas, or anyone who wants a
self-contained offline reference + AI on a drive.

One command asks you **only one thing — where to save the files — then downloads
everything** and writes all the documentation (Markdown **and** HTML). After that, it all
works with **no internet**.

---

## What you get

| Component | What it is | Size (approx) | Needs to run |
|---|---|---|---|
| **Offline AI chat** | 3 local AI models (Llama 3.2 3B, Llama 3.1 8B, Qwen2.5 7B) + CPU & GPU engines (llama.cpp) | ~11 GB | CPU only (GPU optional) |
| **Offline doc-Q&A** | GPT4All — ask an AI questions about your PDFs, with citations | ~0.7 GB | CPU, one-time install |
| **Wikipedia** | Full English Wikipedia (all articles, no images) — Kiwix-readable | ~49 GB | Kiwix |
| **Offline maps** | Maps for the region you pick (**default US**; any country/region/continent — see below) + **bundled desktop viewer** (OsmAndMapCreator + portable Java) + **bundled Android app (APK)** | US ≈17 GB; varies by region (+~0.4 GB tools) | **PC (no phone) or phone** |
| **Repair archive** | iFixit — cars, appliances, electronics, phones | ~3.4 GB | Kiwix |
| **DIY archive** | Appropedia — plumbing, electrical, construction, energy, water, food | ~0.6 GB | Kiwix |
| **Medical** | Offline medical Wikipedia (WikiMed) + curated medical guide | ~1.8 GB | Kiwix |
| **Survival** | Post-disaster, water, food prep, knots (zimgit) | ~0.8 GB | Kiwix |
| **Education** *(opt-in)* | Khan Academy archive (one file, all videos) **or** Kolibri app (pick subjects/low-res) | KA ZIM ~168 GB; Kolibri = your choice | Kiwix / Kolibri app |
| **Army manuals** | Public-domain US Army field/technical manuals (survival, first aid, hand tools, carpentry, auto mechanics, rigging, field cooking) | ~0.2 GB | Any browser (PDF) |
| **Medical books** | *Where There Is No Doctor / No Dentist* (Hesperian) | ~60 MB | Any browser (PDF) |
| **Radio guide** | How ham/CB/shortwave/GMRS radio works + emergency comms | tiny | Any browser |
| **Kiwix reader** | Portable app to read all `.zim` archives (no install) | ~0.15 GB | — |
| **Phone apps** | Bundled Android APKs (Kiwix + OsmAnd) to port the library to a phone offline | ~0.4 GB | sideload on Android |
| **Total** | | **≈ 85 GB** | |

Everything is **free and legally redistributable** — open-weight AI models, openly-licensed
Kiwix archives, and public-domain US-government manuals. **No piracy.**

---

## 📦 Storage requirements — what kind of drive do I need?

The full library is **~85 GB**. Always leave headroom (for the AI's temp files, GPT4All
install, and future updates), so plan for more than 60 GB.

| Drive | Recommendation |
|---|---|
| **Minimum** | **128 GB** drive (full library + working room) |
| **Comfortable** | **256 GB** drive (room to add your own files, Survivor Library, etc.) |
| **USB flash drive** | Works for **storage + reading** PDFs/Wikipedia/maps. Use **USB 3.0+ / 128 GB+**. Cheap flash drives are slow — fine for reading, slow for AI. |
| **External SSD** ⭐ | **Best choice.** Running the AI models from an SSD is far faster than from a flash drive or spinning disk. A 256 GB+ USB-C SSD is ideal. |
| **Internal HDD/SSD** | Perfect if you're keeping it on a PC. |

> **Tip:** If you only want the reference material (no AI), you can skip the big pieces
> with `-SkipModels` and still get Wikipedia, maps, and all manuals in ~30 GB. If you also
> skip Wikipedia and maps (`-SkipWikipedia -SkipMaps`), the AI + manuals fit in ~20 GB. (Wikipedia is now ~49 GB.)
>
> **Adding Khan Academy?** It's **opt-in** and **~168 GB with videos** — budget for a
> **256 GB+** (ideally 512 GB) drive if you include `-Education`.

---

## 💻 Hardware requirements — what machine do I need to USE it?

**Planning for an outage?** Read [Power and devices](docs/POWER-AND-DEVICES.md)
([offline HTML](docs/POWER-AND-DEVICES.html)) for Wh budgets, charging options
and lower-power ways to read the library.

**To download:** any 64-bit **Windows, macOS, or Linux** computer with internet.
- Windows: uses `curl` + PowerShell (both built in).
- macOS/Linux: uses `curl` + `tar` (built in); `unzip` enables the desktop map viewer.
- **Optional but recommended: install [`aria2`](https://aria2.github.io/).** If `aria2c`
  is on your PATH, the installer uses it automatically for **much faster** multi-connection
  downloads (big win on the large files). Falls back to `curl` if it's absent or you pass
  `-NoAria`/`--no-aria`.

Downloading ~85 GB can take several hours.

**To use it afterward (offline):**

| Task | Needs |
|---|---|
| Read PDFs, HTML guides, Wikipedia, maps | **Any computer** with a web browser. Even an old/weak PC. |
| Read `.zim` archives | **Kiwix** — bundled portable on Windows & Linux; on macOS install Kiwix (App Store/kiwix.org). |
| **Offline AI — small model (3B)** | Any 64-bit PC, **~4 GB RAM**. Works on CPU; no graphics card needed. |
| **Offline AI — big model (8B)** | **~8 GB RAM** recommended. CPU only. |
| **Offline AI — GPU model (Qwen 7B)** | A graphics card with **~6 GB VRAM** (NVIDIA/AMD/Intel) for a big speed boost. Optional. |
| **GPT4All doc-Q&A** | 64-bit PC, ~8 GB RAM recommended. CPU only. Self-contained (no Python/CUDA). |
| **Maps on a computer** | **No phone needed** — bundled desktop viewer (OsmAndMapCreator) + bundled portable Java. First use unzips maps (~30 GB). |
| **Maps on a phone** | Android: bundled **OsmAnd~ APK** (sideload offline). iPhone/iPad: install **OsmAnd** from the App Store while online. |

**Key points:**
- **No GPU is required** for the AI — it runs on an ordinary CPU (just slower). A 6 GB GPU
  is a bonus.
- The AI engine ships **x64, ARM64, and Vulkan-GPU** builds, so it runs on Intel/AMD and
  ARM Windows machines.
- The whole kit is **portable** — copy the `OfflineLibrary` folder to any PC and use it.

---

## 🚀 How to download (pick one)

### A) Easiest — double-click `install.bat`
Download/clone the repo, then **double-click `install.bat`**. It opens a window, asks you
where to save, and downloads everything. No commands, no PowerShell knowledge needed.
(If Windows SmartScreen warns, click **More info → Run anyway**.)

### B) In Claude Code (one prompt)
Install this repo's skill, then say:
```
/offline-emergency-library
```
It will ask **only**: *"Where would you like to save these files?"* — then download
everything.

### C) Windows — PowerShell one-liner (no Claude needed)
```powershell
irm https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/Get-OfflineLibrary.ps1 | iex
```
It will prompt you for the save location, then download everything.

### D) macOS / Linux — one-liner
```bash
curl -fsSL https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/get-offline-library.sh | bash
```
It will prompt you for the save location, then download everything.
(Requires `curl` and `tar`; `unzip` enables the desktop map viewer. All are standard.)

### E) Clone and run
```bash
git clone https://github.com/elhajahmadj/offline-emergency-library.git
cd offline-emergency-library
# Windows:
./Get-OfflineLibrary.ps1 -Destination "E:\"
# macOS / Linux:
./get-offline-library.sh -d /path/to/drive
```

**All methods are resumable** — if the download is interrupted, run the same command again
and it continues where it left off.

### Platform support
| | Windows | macOS | Linux |
|---|---|---|---|
| Installer | `Get-OfflineLibrary.ps1` / `install.bat` | `get-offline-library.sh` | `get-offline-library.sh` |
| Offline AI chat | ✅ (x64/ARM + Vulkan GPU) | ✅ (Metal GPU) | ✅ (x64/ARM + Vulkan GPU) |
| GPT4All doc-Q&A | ✅ `.exe` | ✅ `.dmg` | ✅ `.run` |
| Kiwix desktop | ✅ bundled portable | App Store / kiwix.org | ✅ bundled AppImage (x64) |
| Maps on PC | ✅ bundled viewer+Java | ✅ bundled viewer+Java | ✅ bundled viewer+Java |
| All content (Wikipedia, ZIM, PDF, maps, APKs) | ✅ | ✅ | ✅ |

### Quick start with a smaller download

Use `-Lite` (PowerShell) or `--lite` (Bash) to get the **3B AI model**, AI engines,
medical and survival archives, PDF manuals, Kiwix reader, phone apps and regional
maps. It skips full Wikipedia, the 8B/7B models, GPT4All, iFixit and Appropedia.
Only the 3B chat and web-UI launchers are written on a fresh lite install.

```powershell
.\Get-OfflineLibrary.ps1 -Destination "E:\" -Lite -Region US_delaware
```
```bash
./get-offline-library.sh -d /path/to/drive --lite --region US_delaware
```

**This is not a fixed 2-3 GB bundle.** The model, references and bundled tools
already take several GB, and maps vary by region. Maps still default to **US**
(about 17 GB of maps alone); choose a small sub-region as above, or add
`-SkipMaps` / `--skip-maps` to omit maps, their viewer and the OsmAnd app.
Education and Kolibri remain opt-in and can be combined with lite.

To expand later, re-run into the **same destination without the lite flag**.
Existing downloads are resumed/reused; lite does not remove previously downloaded
files or launchers. With no lite flag, the default full-library behavior is unchanged.

---

## 🔐 Trust & verification

This project **hosts nothing** — it downloads from the official upstream sources below and
runs 100% offline afterward:

| What | From |
|---|---|
| AI models (GGUF) | huggingface.co (bartowski) |
| AI engine (llama.cpp) | github.com/ggml-org/llama.cpp |
| GPT4All | github.com/nomic-ai/gpt4all |
| Kiwix reader + ZIM archives | download.kiwix.org |
| Wikipedia | download.kiwix.org |
| Maps + desktop viewer | download.osmand.net |
| Portable Java | api.adoptium.net (Eclipse Temurin) |
| Manuals (PDF) | archive.org |
| Phone apps (APK) | github.com/kiwix/kiwix-android, f-droid.org |
| Education (optional) | download.kiwix.org (Khan Academy ZIM), github.com/learningequality/kolibri (Kolibri app) |

**Verify the installer before running it.** Each script's SHA-256 is published in
[`SHA256SUMS.txt`](SHA256SUMS.txt) and CI checks they stay in sync.

```bash
# macOS / Linux
curl -fsSLO https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/get-offline-library.sh
sha256sum get-offline-library.sh      # compare against SHA256SUMS.txt
bash get-offline-library.sh
```
```powershell
# Windows
irm https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/Get-OfflineLibrary.ps1 -OutFile Get-OfflineLibrary.ps1
Get-FileHash Get-OfflineLibrary.ps1 -Algorithm SHA256   # compare against SHA256SUMS.txt
./Get-OfflineLibrary.ps1
```

The scripts are plain Bash/PowerShell — you're encouraged to read them first. (Hashes match
the files served by GitHub `raw` and the release assets; a `git clone` on Windows rewrites
line endings, so local hashes will differ there.)

---

## 🗺️ Choosing your map region (optional — default is US)

The maps default to the **United States**. To download a different country, region, or
continent, add `-Region` (Windows) / `--region` (macOS/Linux):

```bash
# Windows
./Get-OfflineLibrary.ps1 -Destination "E:\" -Region France
./Get-OfflineLibrary.ps1 -Destination "E:\" -Region "Germany,Austria"
./Get-OfflineLibrary.ps1 -Destination "E:\" -Region Europe      # whole continent
# macOS / Linux
./get-offline-library.sh -d /mnt/usb --region Japan
./get-offline-library.sh -d /mnt/usb --region US_texas          # a sub-region
./get-offline-library.sh -d /mnt/usb --region world             # everything (hundreds of GB!)
```

**Not sure of the name? List what's available (no download):**
```bash
./Get-OfflineLibrary.ps1 -ListRegions              # Windows: all countries/regions
./Get-OfflineLibrary.ps1 -ListRegions -Filter US   # Windows: sub-regions of the US
./get-offline-library.sh --list-regions            # macOS/Linux: all
./get-offline-library.sh --list-regions France     # macOS/Linux: sub-regions of France
```

Accepts a country (`France`), several (`"Germany,Austria"`), a continent (`Europe`,
`Africa`, `Asia`, `North-America`, `South-America`, `Central-America`,
`Australia-Oceania`), a sub-region (`US_texas`, `Germany_bayern`), or `world`.
**Common names and ISO codes also work** (`UK`, `USA`, `GBR`, `DEU`, `JPN`, `UAE`,
`Holland`, `Czech`, …) — they're translated to the right OsmAnd name automatically.
**Size varies:** US ≈17 GB, a small country <1 GB, a continent tens of GB, `world`
hundreds of GB — the installer prints the size and warns before large downloads.

## 🧭 After it finishes

The installer writes a **`README.html`** at the root of the download folder — a full,
clickable **index of every guide, document, manual, archive, app and data file** on the
drive (auto-generated by scanning the folders). Open that first for a complete map of
everything, or **`START-HERE.html`** for a guided intro.

(You can regenerate the index any time with `build-readme-index.ps1 -Root "<folder>"`.)

Both pages link to each component's guide:

- `AI-Offline\HOW-TO-RUN-OFFLINE-AI.html` — run the offline AI chat
- `AI-Offline\DocReader-GPT4All\HOW-TO-ASK-YOUR-DOCS.html` — ask AI about your PDFs
- `Kiwix-Reader\HOW-TO-USE-KIWIX.html` — read the `.zim` archives
- `OsmAnd\HOW-TO-VIEW-MAPS.html` — view maps on a PC (no phone) or phone
- `Phone-Apps\USE-ON-PHONE.html` — port the library to a phone
- `Manuals\READ-ME-FIRST.html` and `Medical\READ-ME-FIRST.html`
- `Manuals\Radio-Communications\RADIO-GUIDE.html` — emergency radio comms
- `Education\READ-ME-FIRST.html` — Khan Academy offline (opt-in)
- `Education\HOW-TO-KOLIBRI.html` — Kolibri learning app, pick subjects/low-res (opt-in)

---

## 🧪 Keep it safe: two copies + CHECK-DRIVE

A single drive is a single point of failure: it can be lost, dropped, or slowly corrupted
(bit rot). Do these three things:

1. **Keep two copies.** Copy the whole `OfflineLibrary` folder to a second drive, and store
   that drive in a different place.
2. **Check both drives every few months.** At the end of every install, the installer writes
   **`CHECKSUMS-SHA256.txt`**: one SHA-256 fingerprint for every file on the drive. It also
   puts **CHECK-DRIVE** next to it, which re-reads every file and prints only the problems.
   It ends with `RESULT: ALL <n> FILES OK.` or a list of damaged or missing files.
3. **Fix a damaged file** by copying it from the other drive. Or delete it and re-run the
   installer, which downloads anything that is missing (it does not re-check files that are
   already there).

**Run CHECK-DRIVE before you re-run the installer.** Each run writes a new list from the files
as they are at that moment, so a file that was already damaged would be listed as good.

| OS | Double-click | Or in a terminal, inside the `OfflineLibrary` folder |
|---|---|---|
| Windows | `CHECK-DRIVE.bat` | `powershell -ExecutionPolicy Bypass -File check-drive.ps1` |
| macOS | `CHECK-DRIVE.command` | `shasum -a 256 -c -q CHECKSUMS-SHA256.txt` |
| Linux | — | `sha256sum -c --quiet CHECKSUMS-SHA256.txt` |

The list uses relative paths (`./Medical/...`), so it works on a copy too: run CHECK-DRIVE on
the second drive the same way. On a large drive a full check reads every byte, so it takes a
while (roughly the time it takes to copy the drive).

**exFAT** is the best format for a drive used on Windows, macOS and Linux, but it has no
journal: pulling the drive out during a write can damage files. Always **eject** it first.
macOS also writes small `._*` files on exFAT drives; CHECK-DRIVE ignores them.

> `CHECKSUMS-SHA256.txt` on the drive covers the **library**. The repo's
> [`SHA256SUMS.txt`](SHA256SUMS.txt) covers only the **installer scripts** (see
> Trust & verification above).

---

## Options (optional, for small drives)

| Flag | Effect |
|---|---|
| `-Lite` / `--lite` | Quick start: 3B AI + medical/survival references + regional maps; omit Wikipedia, larger models, GPT4All, iFixit and Appropedia (see size note above) |
| `-Region <name>` / `--region <name>` | Choose map region (default `US`); country, continent, sub-region, or `world` |
| `-ListRegions` / `--list-regions [filter]` | List available map regions, then exit (no download) |
| `-Education` / `--education` | **Add Khan Academy** archive (Kiwix ZIM, ~168 GB with videos) — off by default |
| `-EduLang <en\|es\|fr>` / `--edu-lang <…>` | Khan Academy language (default `en`) |
| `-Kolibri` / `--kolibri` | **Add the Kolibri learning app** (pick subjects + low-res in-app; tens of GB) — off by default |
| `-SkipWikipedia` / `--skip-wikipedia` | Don't download the 24 GB Wikipedia dump (~24 GB saved) |
| `-SkipMaps` / `--skip-maps` | Don't download the maps (~17 GB saved for US) |
| `-SkipModels` / `--skip-models` | Skip the large 8B/7B AI models, keep the small 3B (~9 GB saved) |
| `-NoAria` / `--no-aria` | Force `curl` even if `aria2c` is installed |

Example: `./Get-OfflineLibrary.ps1 -Destination "F:\" -SkipWikipedia -SkipMaps`

---

## ⚠️ Disclaimers

- Offline AIs and older manuals **can be wrong or outdated**. Verify anything
  safety-critical (medical, electrical, structural) against authoritative sources when
  possible. This kit is reference material, **not** professional advice.
- Modern copyrighted code books (NEC/UPC) and brand auto manuals (Haynes/Chilton) are
  **not** included. Their topics are covered by the openly-licensed iFixit/Appropedia
  archives and public-domain Army technical manuals.
- Respect your local laws for radio transmission (listening is always fine; see the radio
  guide).

## ⭐ Star history
[![Star History Chart](https://api.star-history.com/svg?repos=elhajahmadj/offline-emergency-library&type=Date)](https://star-history.com/#elhajahmadj/offline-emergency-library&Date)

## Contributing
Issues and PRs welcome — see [CONTRIBUTING](.github/CONTRIBUTING.md), the
[ROADMAP](ROADMAP.md), and issues labeled **good first issue**. Testers for the macOS/Linux
installers especially wanted.

Release history and contributor credits are in the [CHANGELOG](CHANGELOG.md). Thanks to
everyone who has tested the installers on real hardware and reported what broke.

## License
Code and documentation in this repo: **MIT** (see `LICENSE`). Downloaded content retains
its original licenses (open-weight model licenses, CC licenses for Kiwix content, public
domain for US-government works).

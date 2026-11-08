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

## Start here

You need a computer with internet and a drive with **128 GB or more free** (an external SSD
is best). The download is about 85 GB and can take several hours.

**Windows**
1. [Download this project as a ZIP](https://github.com/elhajahmadj/offline-emergency-library/archive/refs/heads/main.zip),
   right-click it and choose **Extract All**.
2. In the extracted folder, double-click **`install.bat`**. If Windows says "Windows
   protected your PC", click **More info**, then **Run anyway**.
3. Press Enter to install everything (or see [Pick what to install](#pick-what-to-install)).
   Then type where to save the files, for example `E:\`, and press Enter.

**Mac**
1. [Download this project as a ZIP](https://github.com/elhajahmadj/offline-emergency-library/archive/refs/heads/main.zip).
   If the Mac does not open it for you, double-click it in Downloads.
2. In the folder, double-click **`install.command`**. The first time, the Mac says
   *"install.command" Not Opened*: click **Done**, open **System Settings > Privacy & Security**,
   click **Open Anyway** (twice), and type your password.
3. Press Return to install everything (or see [Pick what to install](#pick-what-to-install)).
   Then type where to save the files, for example `/Volumes/MyDrive`, and press Return.

**Linux**
1. Open a terminal.
2. Paste this line and press Enter:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/get-offline-library.sh | bash
   ```
3. Type where to save the files, for example `/media/you/MyDrive`, and press Enter.

Or use the ZIP, like Windows and Mac: extract it, open a terminal in the folder and run
`bash install.sh`. The file is not marked as executable, so start it with `bash` (or run
`chmod +x install.sh` first). It asks the same first question as the other launchers.

Leave the window open until it says **Finished**, then open
**`START-HERE.html`** in the `OfflineLibrary` folder it made there. If the download stops, run it again the same
way: it carries on where it left off.

### Pick what to install

`install.bat`, `install.command` and `install.sh` first ask **How would you like to install?**
and offer two choices:

- **A**, or just Enter: install everything. The installer then asks only where to save the files.
- **P**: pick what to install. The launcher opens the picker page, `web/index.html`, in your
  browser. Tick what you want, then use the button near the bottom of the page to save your
  selection. It saves a `selection.json` file to your Downloads folder. Go back to the launcher
  window and press a key (Return on Mac and Linux). The launcher takes the newest
  `selection*.json` in Downloads, shows what it will install, and asks you to confirm before it
  downloads anything. This is the same as
  [installing from a selection file](#install-from-a-selection-file).

The picker page needs the kit's `web/` folder next to the launcher. The ZIP has it. If
`web/index.html` is not there, or there is no `selection*.json` in Downloads, the launcher says so
and asks whether to install everything instead. Type `y` for a full install. Any other answer
stops, with nothing downloaded.

Smaller drive, another country's maps, or extra content? See
[Advanced: options and flags](#advanced-options-and-flags).

---

## What you get

| Component | What it is | Size (approx) | Needs to run |
|---|---|---|---|
| **Offline AI chat** | 3 local AI models (Llama 3.2 3B, Llama 3.1 8B, Qwen2.5 7B) + CPU & GPU engines (llama.cpp) | ~11 GB | CPU only (GPU optional) |
| **Offline doc-Q&A** | GPT4All — ask an AI questions about your PDFs, with citations | ~0.7 GB | CPU, one-time install |
| **Wikipedia** | Full English Wikipedia (all articles, no images) — Kiwix-readable | ~49 GB | Kiwix |
| **Browser maps** *(opt-in)* | US street maps that open in **any web browser** (Project NOMAD / Protomaps + MapLibre viewer + Caddy), `-BrowserMaps` / `--browser-maps` | US ≈16.5 GB (one state: less) | **Any computer** with a browser |
| **Offline maps** | Maps for the region you pick (**default US**; any country/region/continent — see below) + **bundled desktop viewer** (OsmAndMapCreator + portable Java; needs internet on Windows/macOS, see below) + **bundled Android app (APK)** | US ≈17 GB; varies by region (+~0.4 GB tools) | **PC (no phone) or phone** |
| **Repair archive** | iFixit — cars, appliances, electronics, phones | ~3.4 GB | Kiwix |
| **DIY archive** | Appropedia — plumbing, electrical, construction, energy, water, food | ~0.6 GB | Kiwix |
| **Medical** | Offline medical Wikipedia (WikiMed) | ~1.8 GB | Kiwix |
| **Survival & preparedness** | FEMA *Are You Ready?*, EPA water disinfection, knots guide, *Hunting with the Bow & Arrow* (Pope, 1923), Kephart's *Book of Camping and Woodcraft* (1910), *Deadfalls and Snares* (1907), *Bait Angling for Common Fishes* (1907) (public domain) | ~90 MB | Browser (PDF) |
| **Household DIY** | *The Boy Mechanic, Vol. 1: 700 Things to Do* (1913, public domain) — make-it-yourself projects from common materials; dated, some projects unsafe by modern standards (see manuals README) | ~50 MB | Browser (PDF) |
| **Metalworking** | Army TM 9-237 *Welding Theory and Application*, *Practical Blacksmithing* (1888), *Elements of Machine Work* (1910) (public domain) | ~70 MB | Browser (PDF) |
| **Food growing** | *Productive Vegetable Growing* (Lloyd, 1918), *Productive Poultry Husbandry* (Lewis, 1913), *Langstroth on the Hive and the Honey-Bee* (1904) (public domain) | ~55 MB | Browser (PDF) |
| **Natural medicine** | *King's American Dispensatory* (Felter & Lloyd) + Culpeper's *Complete Herbal* (public domain) — historical herbal/medicinal-plant references, **not** current medical advice (see [medical guide](docs/Medical-READ-ME-FIRST.md)) | ~175 MB | Browser (PDF) |
| **Education** *(opt-in)* | Khan Academy archive (one file, all videos) **or** Kolibri app (pick subjects/low-res) | KA ZIM ~168 GB; Kolibri = your choice | Kiwix / Kolibri app |
| **Offline translator** *(opt-in)* | Two-way text translator for talking with someone who speaks another language; a small multilingual AI model (Qwen3 4B, Apache 2.0) on the bundled llama.cpp engine, `-Translate` / `--translate`. Good for widely spoken languages, weak or unusable for some others ([guide](docs/HOW-TO-TRANSLATE.md)) | ~2.5 GB | CPU, ~6 GB RAM |
| **Extra archives** *(opt-in)* | Wikivoyage travel guide + Wikibooks open textbooks (English, with images), `-ExtraZims` / `--extra-zims` | ~5.8 GB | Kiwix |
| **Health topics** *(opt-in)* | MedlinePlus plain-language health topic summaries (US National Library of Medicine, public domain), English + Spanish, one searchable page for any browser, `-MedlinePlus` / `--medlineplus`; see the [medical guide](docs/Medical-READ-ME-FIRST.md) | ~30 MB | Any browser |
| **Army manuals** | Public-domain US Army field/technical manuals (survival, first aid, field hygiene & sanitation, hand tools, carpentry, concrete & masonry, water supply & purification, auto mechanics, rigging, field cooking, desert operations, map reading & land navigation, cold weather) | ~0.3 GB | Any browser (PDF) |
| **Medical books** | *Where There Is No Doctor / No Dentist* (Hesperian) | ~60 MB | Any browser (PDF) |
| **Delayed-care guide** | *A Practical Guide to Prolonged Casualty Care* (USUHS + Henry M. Jackson Foundation, 2025; CC BY-NC-SA 4.0) — advanced care when help is hours or days away; not a substitute for a clinician | ~15 MB | Any browser (PDF) |
| **Childbirth references** | WHO *Managing complications in pregnancy and childbirth* (2017) + *Recommendations on maternal health* (2025); trained-worker references with update cautions and CC BY-NC-SA 3.0 IGO terms in the [medical guide](docs/Medical-READ-ME-FIRST.md) | ~9 MB | Any browser (PDF) |
| **Emergency childbirth** | *Emergency Childbirth* (US Office of Civil Defense / Public Health Service, public domain) — plain-language guide to delivering a baby when skilled help is delayed | <1 MB | Any browser (HTML) |
| **Home canning** | *USDA Complete Guide to Home Canning* (2015 revision; US-government work) — safe canning of fruit, tomatoes, vegetables, meat, pickles, jams; plus USDA *Canning, Freezing, Storing Garden Produce* (1977) | ~18 MB | Any browser (PDF) |
| **Radio guide** | How ham/CB/shortwave/GMRS radio works + emergency comms | tiny | Any browser |
| **Kiwix reader** | Portable app to read all `.zim` archives (no install) | ~0.15 GB | — |
| **Phone apps** | Bundled Android APKs (Kiwix + OsmAnd) to port the library to a phone offline | ~0.4 GB | sideload on Android |
| **Total** | | **≈ 85 GB** | |

Everything is **free and legally redistributable** — open-weight AI models, openly-licensed
Kiwix archives and guides, and public-domain US-government manuals. **No piracy.**

---

## 📦 Storage requirements — what kind of drive do I need?

The full library is **~85 GB**. Always leave headroom (for the AI's temp files, GPT4All
install, and future updates), so plan for more than 100 GB.

Before the first download, the installer prints a size estimate for the options you chose
(maps for your region and every opt-in included) next to the free space, and warns if it
will not fit.

| Drive | Recommendation |
|---|---|
| **Minimum** | **128 GB** drive (full library + working room) |
| **Comfortable** | **256 GB** drive (room to add your own files, Survivor Library, etc.) |
| **USB flash drive** | Works for **storage + reading** PDFs/Wikipedia/maps. Use **USB 3.0+ / 128 GB+**. Cheap flash drives are slow — fine for reading, slow for AI. |
| **External SSD** ⭐ | **Best choice.** Running the AI models from an SSD is far faster than from a flash drive or spinning disk. A 256 GB+ USB-C SSD is ideal. |
| **Internal HDD/SSD** | Perfect if you're keeping it on a PC. |

> **Tip:** Wikipedia (~49 GB) and US maps (~17 GB) are the big pieces. `-SkipModels` drops
> only the 8B and 7B AI models (~9 GB; the small 3B model stays), so the library is still
> ~77 GB. `-SkipWikipedia -SkipMaps` leaves the AI and all manuals in ~20 GB; add
> `-SkipModels` too for ~11 GB. The installer prints the estimate for your choices first.
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
| **Offline translator** *(opt-in)* | 64-bit PC, **~6 GB RAM** (about 4.8 GB in use while it runs). CPU only. |
| **GPT4All doc-Q&A** | 64-bit PC, ~8 GB RAM recommended. CPU only. Self-contained (no Python/CUDA). |
| **Maps on a computer** | **No phone needed.** Offline: browser maps (US, `-BrowserMaps`). The bundled desktop viewer (OsmAndMapCreator + portable Java) draws online tiles on Windows and macOS, so it is blank with no internet ([#15](https://github.com/elhajahmadj/offline-emergency-library/issues/15)); use an Android phone for non-US offline maps. First use of the desktop viewer unzips maps (~30 GB). |
| **Maps on a phone** | Android: bundled **OsmAnd~ APK** (sideload offline). iPhone/iPad: install **OsmAnd** from the App Store while online. |

**Key points:**
- **No GPU is required** for the AI — it runs on an ordinary CPU (just slower). A 6 GB GPU
  is a bonus.
- The AI engine ships **x64, ARM64, and Vulkan-GPU** builds, so it runs on Intel/AMD and
  ARM Windows machines.
- The whole kit is **portable** — copy the `OfflineLibrary` folder to any PC and use it.

---

## 🚀 Other ways to install

### A) Double-click `install.bat` (Windows) or `install.command` (Mac)
The steps are in [Start here](#start-here) at the top of this page. On Linux, run
`bash install.sh` in the extracted ZIP. All three launchers first offer the
[pick-or-install-everything menu](#pick-what-to-install).

### B) In Claude Code (one prompt)
Install this repo's skill, then say:
```
/offline-emergency-library
```
It will ask **only**: *"Where would you like to save these files?"* — then download
everything.

### C) Windows - PowerShell (no Claude needed)
```powershell
irm https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/Get-OfflineLibrary.ps1 -OutFile Get-OfflineLibrary.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-OfflineLibrary.ps1
```
It will prompt you for the save location, then download everything. Run the saved file
rather than piping it to `iex`: piped, the installer's exit closes the PowerShell window and
any error message with it.

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
| Installer | `Get-OfflineLibrary.ps1` / `install.bat` | `get-offline-library.sh` / `install.command` | `get-offline-library.sh` / `install.sh` |
| Offline AI chat | ✅ (x64/ARM + Vulkan GPU) | ✅ (Metal GPU) | ✅ (x64/ARM + Vulkan GPU) |
| GPT4All doc-Q&A | ✅ `.exe` | ✅ `.dmg` | ✅ `.run` |
| Kiwix desktop | ✅ bundled portable | App Store / kiwix.org | ✅ bundled AppImage (x64) |
| Maps on PC | ⚠️ viewer needs internet; offline: browser maps (US) | ⚠️ viewer needs internet; offline: browser maps (US) | viewer bundled (offline untested); browser maps (US) |
| All content (Wikipedia, ZIM, PDF, maps, APKs) | ✅ | ✅ | ✅ |

### Quick start with a smaller download

**Lite still includes all US maps by default (about 17 GB of maps alone).**
Before prompting for a destination or starting downloads, the installers show
the selected map region and flags to choose a smaller area or skip maps.

Use `-Lite` (PowerShell) or `--lite` (Bash) to get the **3B AI model**, AI engines,
medical and survival archives, PDF manuals, Kiwix reader, phone apps and regional
maps. It skips full Wikipedia, the 8B/7B models, GPT4All, iFixit and Appropedia.
Only the 3B chat and web-UI launchers are written on a fresh lite install.

Lite still includes the **Ask the manuals** reader (`AI-Offline\Manual-QA\`): it searches
downloaded manual text, shows the passages behind an answer, and links each one to the
original PDF. It uses the 3B model, so no extra download is needed. It omits GPT4All, so
the **LocalDocs** workflow for indexing your own folders needs a non-lite install (details
in `HOW-TO-ASK-YOUR-DOCS`).

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
| Browser maps (optional) | github.com/Crosstalk-Solutions/project-nomad-maps (maps, style), unpkg.com (MapLibre GL JS, pmtiles.js), github.com/caddyserver/caddy (web server) |
| Portable Java | api.adoptium.net (Eclipse Temurin) |
| Manuals (PDF) | archive.org |
| WHO childbirth references (PDF) | iris.who.int (WHO); citations and noncommercial redistribution terms in the [medical guide](docs/Medical-READ-ME-FIRST.md) |
| Phone apps (APK) | github.com/kiwix/kiwix-android, f-droid.org |
| Education (optional) | download.kiwix.org (Khan Academy ZIM), github.com/learningequality/kolibri (Kolibri app) |
| Extra archives (optional) | download.kiwix.org (Wikivoyage, Wikibooks ZIM) |
| Health topics (optional) | medlineplus.gov/xml.html (MedlinePlus health topic XML, US National Library of Medicine; public domain) |

**Verify the installer before running it.** Each script's SHA-256 is published in
[`SHA256SUMS.txt`](SHA256SUMS.txt), which a workflow regenerates after every merge to `main`.

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
`Africa`, `Asia`, `NorthAmerica`, `SouthAmerica`, `CentralAmerica`,
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

- `I-NEED-TO.html` — **emergency quick index**: "I need to…" → straight to the right file
- `EMERGENCY-ESSENTIALS.html` — **printable one-pager**: critical reminders (bleeding, CPR,
  water, signalling, frequencies) for when the battery is dead — print it while you have power
- `AI-Offline\HOW-TO-RUN-OFFLINE-AI.html` — run the offline AI chat
- `AI-Offline\DocReader-GPT4All\HOW-TO-ASK-YOUR-DOCS.html` — ask AI about your PDFs
- `Kiwix-Reader\HOW-TO-USE-KIWIX.html` — read the `.zim` archives
- `OsmAnd\HOW-TO-VIEW-MAPS.html` — view maps on a PC (no phone) or phone
- `OsmAnd\MAP-AND-COMPASS.html` - [map and compass guide](docs/MAP-AND-COMPASS.md)
  ([offline HTML](docs/MAP-AND-COMPASS.html)): print for navigation without a device
- `Maps-Browser\OPEN-MAPS.bat` / `OPEN-MAPS.sh` — street maps in a web browser (opt-in)
- `Phone-Apps\USE-ON-PHONE.html` — port the library to a phone
- `Manuals\READ-ME-FIRST.html` and `Medical\READ-ME-FIRST.html`
- `Medical\PSYCHOLOGICAL-FIRST-AID.html` — helping people (and yourself) cope with panic,
  fear, grief and stress in a crisis
- `Manuals\Radio-Communications\RADIO-GUIDE.html` — emergency radio comms
- `Manuals\Radio-Communications\RADIO-FREQUENCIES.html` - printable US frequency tables,
  regional cautions and primary sources (NOAA, FCC, USCG, FAA)
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

## Advanced: options and flags

Add these to the commands in [E) Clone and run](#e-clone-and-run) (see the [Quick start](#quick-start-with-a-smaller-download) examples). The one-liners in C and D cannot take flags as written.
None of them are needed for a normal install.

| Flag | Effect |
|---|---|
| `-Lite` / `--lite` | Quick start: 3B AI + medical/survival references + regional maps; omit Wikipedia, larger models, GPT4All, iFixit and Appropedia (see size note above) |
| `-Region <name>` / `--region <name>` | Choose map region (default `US`); country, continent, sub-region, or `world` |
| `-ListRegions` / `--list-regions [filter]` | List available map regions, then exit (no download) |
| `-Education` / `--education` | **Add Khan Academy** archive (Kiwix ZIM, ~168 GB with videos) — off by default |
| `-EduLang <en\|es\|fr>` / `--edu-lang <…>` | Khan Academy language (default `en`) |
| `-BrowserMaps` / `--browser-maps` | **Add street maps for any web browser** (US states, ~16.5 GB for all, on top of ~17.8 GB of OsmAnd maps, so ~34 GB of maps in total; follows `-Region`) — off by default |
| `-Kolibri` / `--kolibri` | **Add the Kolibri learning app** (pick subjects + low-res in-app; tens of GB) — off by default |
| `-ExtraZims` / `--extra-zims` | **Add Wikivoyage + Wikibooks** (Kiwix ZIM, ~5.8 GB; CC BY-SA) into `Extra-Archives\` — off by default. WikiHow is not on download.kiwix.org today, so it is not included |
| `-Translate` / `--translate` | **Add an offline translator** (Qwen3 4B model, ~2.5 GB; Apache 2.0) with `TRANSLATE.bat` / `translate.sh` in `AI-Offline\` - off by default. Uses the bundled AI engine, so nothing else is installed. See [HOW-TO-TRANSLATE](docs/HOW-TO-TRANSLATE.md) for which languages work |
| `-MedlinePlus` / `--medlineplus` | **Add MedlinePlus health topics** (~30 MB; public domain) as one offline page, `Medical\MedlinePlus\MedlinePlus-Health-Topics.html` - off by default. Summaries only: the copyrighted encyclopedia and drug pages are not included |
| `-SkipWikipedia` / `--skip-wikipedia` | Don't download the Wikipedia dump (~49 GB saved) |
| `-SkipMaps` / `--skip-maps` | Don't download the maps (~17 GB saved for US) |
| `-SkipModels` / `--skip-models` | Skip the large 8B/7B AI models, keep the small 3B (~9 GB saved) |
| `-Only <piece>[,<piece>]` / `--only <piece>[,<piece>]` | **Add just these pieces to a drive you already made** (see below). Pieces: `translate`, `medlineplus`, `extra-zims`, `browser-maps`, `education`, `kolibri`, `wikipedia`. Cannot be combined with `-Lite`, the `-Skip` options or the piece switches above |
| `-Selection <file>` / `--select <file>` | **Fresh install of just the pieces named in a selection file** (see below). Cannot be combined with `-Only`, `-Lite`, the `-Skip` options, `-Region` or the piece switches |
| `-CheckSelection` / `--check-selection` | With `-Selection` / `--select`: show what the file would install, then stop (nothing is created or downloaded) |
| `-NoAria` / `--no-aria` | Force `curl` even if `aria2c` is installed |

Example: `./Get-OfflineLibrary.ps1 -Destination "F:\" -SkipWikipedia -SkipMaps`

### Add one piece to a finished drive

To add something later without re-running the whole install, point the installer at the same
destination with `-Only` (Windows) or `--only` (macOS/Linux):

```
.\Get-OfflineLibrary.ps1 -Destination "F:\" -Only translate
./get-offline-library.sh -d /mnt/usb --only translate,medlineplus
```

It downloads only those pieces, then rebuilds `README.html`, `CHECKSUMS-SHA256.txt` (a full
read of the drive, so it takes a while on a big drive) and runs the self-check. It stops with a
plain message, before downloading anything, if the folder is not a finished library or a piece
needs something the drive lacks: `translate` needs the AI engine. Nothing is installed for you
in that case. `browser-maps` follows `-Region` / `--region` and `education` follows
`-EduLang` / `--edu-lang`, as in a full install.

### Install from a selection file

A selection file names the pieces to install and the map regions. The piece ids, what each
one needs and their sizes are in [`catalog.json`](catalog.json):

```
{"pieces": ["core", "maps", "medlineplus"], "regions": ["US_delaware"]}
```

```
.\Get-OfflineLibrary.ps1 -Destination "F:\" -Selection selection.json
./get-offline-library.sh -d /mnt/usb --select selection.json
```

The installer turns the file into the usual options (it prints them as `Same as: ...`) and
runs a normal fresh install:

- `core` is always installed, so every selection names it.
- `models` (8B + 7B) and `wikipedia` need `gpt4all-repair` (GPT4All, iFixit, Appropedia).
  Leaving `gpt4all-repair` out is the `-Lite` / `--lite` preset.
- `browser-maps` needs `maps`. `regions` need `maps`; `maps` with no `regions` gets the US.
- An unknown piece, a missing piece that another one needs, or a file of any other shape
  stops the installer before it creates or downloads anything.

Add `-CheckSelection` / `--check-selection` to see what a file means without installing.
To add pieces to a drive that is already finished, use `-Only` / `--only` instead.
The launchers can make the file and run this for you: see [Pick what to install](#pick-what-to-install).

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
its original licenses. The table below lists each bundled source, its license, and whether
it may be redistributed **commercially** (i.e. whether you could sell a loaded drive). Where
each source is downloaded from is in [Trust & verification](#-trust--verification) above.

| Source | License | Commercial reuse? |
|---|---|---|
| Offline AI models — Llama 3.2 3B, Llama 3.1 8B | [Llama 3.2](https://www.llama.com/llama3_2/license/) / [Llama 3.1](https://www.llama.com/llama3_1/license/) Community License | Yes, under the license terms (incl. the >700M-MAU clause). Distributing a copy — not only selling — requires a "Built with Llama" notice and the Meta `Notice` text ⁂ |
| Offline AI model — Qwen2.5 7B, and translator Qwen3 4B | Apache-2.0 | Yes |
| AI engine (llama.cpp), GPT4All, Kolibri app, project-nomad-maps repo | MIT (project-nomad-maps also ships fonts under [SIL OFL](https://openfontlicense.org/)) | Yes |
| MapLibre GL JS, pmtiles.js | BSD-3-Clause | Yes |
| Caddy web server | Apache-2.0 | Yes |
| Portable Java (Eclipse Temurin / OpenJDK) | GPL-2.0 WITH Classpath-exception | Yes |
| Kiwix reader; Kiwix / OsmAnd~ phone apps | GPL-3.0 | Yes |
| OsmAnd maps viewer (OsmAndMapCreator) + OsmAnd~ app | GPL-3.0 (code); artwork [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/), some proprietary (TTS voices) | Code yes; bundled artwork **non-commercial** |
| Map data (OpenStreetMap; OsmAnd + Protomaps basemap) | [ODbL-1.0](https://opendatacommons.org/licenses/odbl/1-0/) | Yes (attribution + share-alike) |
| Wikipedia, WikiMed medical; Appropedia DIY; Wikivoyage + Wikibooks (opt-in) | CC BY-SA | Yes (attribution + share-alike) |
| US Army field/technical manuals | US government works (public domain) ⸸ | Yes |
| USDA *Complete Guide to Home Canning* (AIB 539) | US government work (public domain) | Yes |
| FEMA *Are You Ready?* (IS-22) | US government work (public domain) | Yes |
| EPA *Emergency Disinfection of Drinking Water* | US government work (public domain) | Yes |
| USDA *Canning, Freezing, Storing Garden Produce* (AIB 410, 1977) | US government work (public domain) | Yes |
| Verrill, *Knots, Splices and Rope Work* (1912) | Public domain in the US (published 1912) | Yes |
| Pope, *Hunting with the Bow and Arrow* (1923) | Public domain in the US (published 1923) | Yes |
| *The Boy Mechanic, Vol. 1* (1913) | Public domain in the US (published 1913) | Yes |
| *King's American Dispensatory* (Felter & Lloyd, 1898/1905) | Public domain in the US (pre-1929) | Yes |
| Culpeper, *The Complete Herbal* (1653; this ed. pre-1929) | Public domain | Yes |
| Lloyd, *Productive Vegetable Growing* (1918) | Public domain in the US (published 1918) | Yes |
| Lewis, *Productive Poultry Husbandry* (1913) | Public domain in the US (published 1913) | Yes |
| *Langstroth on the Hive and the Honey-Bee* (1904) | Public domain in the US (published 1904) | Yes |
| *Practical Blacksmithing* (1888) | Public domain in the US (published 1888) | Yes |
| *Elements of Machine Work* (1910) | Public domain in the US (published 1910) | Yes |
| Kephart, *The Book of Camping and Woodcraft* (1910) | Public domain in the US (published 1910) | Yes |
| Harding, *Deadfalls and Snares* (1907) | Public domain in the US (published 1907) | Yes |
| Rhead, *Bait Angling for Common Fishes* (1907) | Public domain in the US (published 1907) | Yes |
| *Emergency Childbirth* (US Office of Civil Defense / PHS; Project Gutenberg #26923 e-text) | US government work (public domain) | Yes |
| MedlinePlus health topics (opt-in) | Public domain (US NLM) — **summaries only** | Yes |
| iFixit repair archive | [CC BY-NC-SA 3.0](https://creativecommons.org/licenses/by-nc-sa/3.0/) | **No — non-commercial** |
| *A Practical Guide to Prolonged Casualty Care* | [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) | **No — non-commercial** |
| WHO childbirth / maternal-health references | [CC BY-NC-SA 3.0 IGO](https://creativecommons.org/licenses/by-nc-sa/3.0/igo/) | **No — non-commercial** |
| *Where There Is No Doctor* / *No Dentist* (Hesperian) | Non-commercial (copies free or at cost, not for profit) | **No — non-commercial** |
| Khan Academy archive (opt-in) | CC BY-NC-SA | **No — non-commercial** |

> **MedlinePlus caveat:** only the **public-domain topic summaries** are bundled. The
> A.D.A.M. medical encyclopedia and ASHP drug pages inside the full MedlinePlus data are
> **copyrighted** and are **not** included.
>
> **⁂ Llama notice duty:** anyone who distributes the Llama models (giving copies away, not
> only selling) must display "Built with Llama" and keep Meta's `Notice` text. We are adding
> those files to the model folder; until then, honor the duty if you pass a drive on.
>
> **⸸ Two Army manuals are not plain public-release works:** *FM 3-05.70* (2002) is
> distribution-restricted ("U.S. Government agencies and their contractors only"), and
> *FM 21-11 First Aid for Soldiers* contains American Heart Association copyrighted material.
> The rest are public-release US government works.

**In short: do not sell a drive made with this kit; giving copies away is fine.** Several
sources above are non-commercial (iFixit, Prolonged Casualty Care, the WHO references,
the Hesperian books, OsmAnd's bundled artwork, and the opt-in Khan Academy archive), which
blocks reselling a loaded drive even though giving copies away is allowed.

# 🛟 Offline Emergency Kit — START HERE

This drive is a self-contained **offline survival library + AI**. Everything works with
**no internet**. This page explains what's here and how to open each part.

> 🆘 **In an emergency right now?** Open **[I need to…](I-NEED-TO.html)** — a task-first
> index that sends you straight to the right file for bleeding, CPR, water, calling for
> help, navigation and more.
>
> 🖨️ **Before the battery dies:** print **[Emergency essentials](EMERGENCY-ESSENTIALS.html)**
> — one page of the most critical reminders (bleeding, CPR, water, signalling, frequencies)
> that works on paper with no power.

> **How this kit is meant to be used:** the books, manuals and maps are the authority.
> The offline AI is a fast
> **assistant**: it helps you *find and digest* the library - search it, summarize it,
> cross-reference it. For anything safety-critical (medical doses, water treatment,
> first-aid steps), read the manual itself and follow it.

> **Windows vs macOS/Linux:** launchers are `.bat` files on Windows and `.sh` files on
> macOS/Linux (run them from a terminal). The content, PDFs, HTML guides, and phone apps
> are identical on every platform.

> **Three ways to read and use things on this drive:**
> - **PDFs and these guides (.html)** open in **Edge or any web browser** — no software.
> - **`.zim` archives** open in **Kiwix** (portable, no install) — see
>   `E:\Kiwix-Reader\`.
> - **Ask questions of the bundled docs** = **GPT4All LocalDocs** - see
>   `E:\AI-Offline\DocReader-GPT4All\`.

---

## What's on this drive

| Folder | What it is | How to open | Guide |
|---|---|---|---|
| `AI-Offline\` | Offline AI chat - your helper for brainstorming, checklists and summaries (3 models, CPU + GPU) | Double-click a `CHAT-*.bat` | `AI-Offline\HOW-TO-RUN-OFFLINE-AI.html` |
| `AI-Offline\DocReader-GPT4All\` | Ask the **bundled manuals** questions (shows the sources it used) - recommended for medical & survival | Install once, then offline | `...\HOW-TO-ASK-YOUR-DOCS.html` |
| `Manuals\` | Survival & repair manuals (Army FMs, iFixit, Appropedia) | PDF→browser, ZIM→Kiwix | `Manuals\READ-ME-FIRST.html` |
| `Manuals\Radio-Communications\` | How ham/CB/shortwave radio works + emergency comms | Browser | `RADIO-GUIDE.html` |
| `Medical\` | Offline medical Wikipedia + first-aid books | ZIM→Kiwix, PDF→browser | `Medical\READ-ME-FIRST.html` |
| `Wikipedia\` | Full Wikipedia (all articles, no images) | Kiwix | — |
| `Education\` | Courses + videos (opt-in): Khan Academy archive (Kiwix) **or** Kolibri app (pick subjects) | Kiwix / Kolibri | `Education\READ-ME-FIRST.html`, `Education\HOW-TO-KOLIBRI.html` |
| `Extra-Archives\` | Travel guide (Wikivoyage) + open textbooks (Wikibooks) (opt-in) | Kiwix | `Kiwix-Reader\HOW-TO-USE-KIWIX.html` |
| `OsmAnd\` | Offline maps (your chosen region; default US) — view on a PC or phone | PC: `Maps-Browser\OPEN-MAPS.bat` (US, if built with `-BrowserMaps`); `MapViewer-Desktop\VIEW-MAPS-ON-PC.bat` needs internet on Windows/macOS; phone: bundled APK | `OsmAnd\HOW-TO-VIEW-MAPS.html` |
| `OsmAnd\MAP-AND-COMPASS.html` | Paper-map, compass and natural navigation | Print the guide and carry a paper topo map and compass | `OsmAnd\MAP-AND-COMPASS.html` |
| `Kiwix-Reader\` | The reader for all `.zim` archives | Portable app | `Kiwix-Reader\HOW-TO-USE-KIWIX.html` |
| `Maps-Browser\` | Street maps in a web browser (opt-in, US) | `OPEN-MAPS.bat` / `OPEN-MAPS.sh` | `OsmAnd\HOW-TO-VIEW-MAPS.html` |
| `Phone-Apps\` | Android apps (Kiwix + OsmAnd) to port the library to a phone, offline | Sideload the APKs | `Phone-Apps\USE-ON-PHONE.html` |

---

## Launchers on this drive (double-click to run)

Every clickable launcher the installer wrote, and what it does. Which ones are present
depends on what you installed (a **lite** drive skips the 8B and GPU chats; **browser maps**
are opt-in).

| Launcher (Windows / macOS-Linux) | What it does | On a full drive? |
|---|---|---|
| `AI-Offline\CHAT-3B-light.bat` / `chat-3B-light.sh` | Offline AI chat, small **3B** model — ~4 GB RAM, CPU only; best on a weak PC | always |
| `AI-Offline\CHAT-8B-smart.bat` / `chat-8B-smart.sh` | Offline AI chat, larger **8B** model — ~8 GB RAM, smarter answers | full install |
| `AI-Offline\CHAT-GPU-Qwen7B.bat` / `chat-GPU-Qwen7B.sh` | Offline AI chat on a **GPU** (Qwen 7B, ~6 GB VRAM) for a big speed-up | full install |
| `AI-Offline\WEB-UI.bat` / `web-ui.sh` | Offline AI in your **browser** — starts a local server, then open `http://127.0.0.1:8080` | always |
| `AI-Offline\TRANSLATE.bat` / `translate.sh` | Offline **translator** (Qwen3 4B); see `AI-Offline\HOW-TO-TRANSLATE.html` | with `-Translate` / `--translate` |
| `OsmAnd\MapViewer-Desktop\VIEW-MAPS-ON-PC` | Open the **desktop map viewer** (OsmAndMapCreator); first run unzips the maps. **Needs internet on Windows and macOS** (draws online tiles); offline, use browser maps (US) or a phone | with maps |
| `Maps-Browser\OPEN-MAPS.bat` / `.sh` | **Street maps in a web browser** (opt-in browser maps); opens `http://localhost:8097` | with `-BrowserMaps` / `--browser-maps` |
| `CHECK-DRIVE.bat` / `.sh` | **Re-check every file** on the drive for damage and print only the problems | always |

> **Windows vs macOS/Linux:** the chat / Web-UI / translator launchers, `OPEN-MAPS` and
> `CHECK-DRIVE` ship in **both** forms on every drive — `.bat` on Windows and `.sh` on
> macOS/Linux (run them from a terminal); macOS also gets `CHECK-DRIVE.command` for a
> double-click. **`VIEW-MAPS-ON-PC` is the exception:** it's written in just one form,
> matching the OS that built the drive — `.bat` on a Windows-built drive, `.sh` on a
> macOS/Linux-built one. The GPU chat launcher uses Metal on a Mac and Vulkan on Linux.

---

## Quick start by need

- **Prepare for a dead battery:** print `EMERGENCY-ESSENTIALS.html` (one page of critical
  reminders) and your region's map now, while you have power.
- **Navigate without a device:** open `OsmAnd\MAP-AND-COMPASS.html` and print it
  while preparing the kit. Keep a paper topographic map and compass.
- **Keep a device charged off-grid:** read [Power and devices](POWER-AND-DEVICES.html)
  for battery sizing, solar/car charging and low-power reading setups.
- **I want to chat with an AI offline:** `AI-Offline\` → double-click `CHAT-3B-light.bat`
  (great for brainstorming and summaries; for anything safety-critical, follow the manuals).
- **I want the AI to answer from my manuals - recommended for medical & survival questions:**
  set up `DocReader-GPT4All` (see its guide); its **LocalDocs** feature answers from the
  bundled docs and *shows the sources it used*, so you can check them. Point it at
  `Manuals\ArmyFieldManuals` and `Medical\Manuals-PDF`, ask away.
- **I need to fix something (car/appliance/plumbing/electrical):** open Kiwix →
  `Manuals\Repair-iFixit` and `Manuals\DIY-Appropedia`.
- **Medical / first aid:** open Kiwix → `Medical\WikiMed`; or read the PDFs in
  `Medical\Manuals-PDF`; Army first aid in `Manuals\ArmyFieldManuals`.
- **Survival / water / food:** the Army survival PDFs in `Manuals\ArmyFieldManuals` (water,
  food, knots, shelter), plus Appropedia DIY in Kiwix and the USDA canning guide.
- **Communicate by radio:** read `Manuals\Radio-Communications\RADIO-GUIDE.html`.
- **Learn / study (courses + video):** open `Education\` in Kiwix (if you added Khan Academy
  with `-Education` / `--education`; see `Education\READ-ME-FIRST.html`).
- **Talk with someone who speaks another language:** run `AI-Offline\TRANSLATE.bat` (Windows)
  or `translate.sh` (macOS/Linux), if you added it with `-Translate` / `--translate`; see
  `AI-Offline\HOW-TO-TRANSLATE.html` first.
- **What is this illness, symptom or test?** open
  `Medical\MedlinePlus\MedlinePlus-Health-Topics.html` in a browser (if you added it with
  `-MedlinePlus` / `--medlineplus`).
- **Travel guide / textbooks:** open `Extra-Archives\` in Kiwix (if you added them with
  `-ExtraZims` / `--extra-zims`).
- **Look something up:** Wikipedia (via Kiwix) and the maps (`OsmAnd\HOW-TO-VIEW-MAPS.html`
  — works on a PC with no phone).

---

## Dependencies — kept to a minimum

| Content | Needs | Bundled here? |
|---|---|---|
| PDFs & `.html` guides | A web browser (Edge is on Windows) | n/a — already on Windows |
| `.zim` archives | **Kiwix** (portable, no install) | ✅ `E:\Kiwix-Reader\app` |
| Offline AI chat | Nothing extra (self-contained engine) | ✅ `E:\AI-Offline\engine` |
| AI doc-Q&A | **GPT4All** (one-time install; self-contained, CPU) | ✅ installer in `DocReader-GPT4All` |
| Maps on a computer | Bundled desktop viewer + portable Java (needs internet on Windows/macOS; offline use `Maps-Browser` or a phone, #15) | ⚠️ `OsmAnd\MapViewer-Desktop` |
| Maps on Android | Bundled **OsmAnd~ APK** (sideload offline) | ✅ `OsmAnd\PhoneApp-Android` |
| Maps on iPhone/iPad | OsmAnd from the App Store | app store (get while online) |

Everything that needs a one-time online step (GPT4All's first run, phone apps) should be
set up **now, while you still have internet**, so the kit is fully usable offline later.

---

## ⚠️ Reminders

- Offline AIs and old manuals **can be wrong**. Use the AI to find and summarize; for
  anything safety-critical, read the manual itself and follow it.
- Keep the drive **backed up** (a second copy on another drive/USB is wise), and run
  **CHECK-DRIVE** (`CHECK-DRIVE.bat` on Windows, `CHECK-DRIVE.command` on macOS) every few
  months to find damaged files.
- **Practice** using each tool now so it's familiar in an actual emergency.

# 🛟 Offline Emergency Kit — START HERE

This drive is a self-contained **offline survival library + AI**. Everything works with
**no internet**. This page explains what's here and how to open each part.

> **Windows vs macOS/Linux:** launchers are `.bat` files on Windows and `.sh` files on
> macOS/Linux (run them from a terminal). The content, PDFs, HTML guides, and phone apps
> are identical on every platform.

> **Two things to read things on this drive:**
> - **PDFs and these guides (.html)** open in **Edge or any web browser** — no software.
> - **`.zim` archives** open in **Kiwix** (portable, no install) — see
>   `E:\Kiwix-Reader\`.
> - **AI that answers from your PDFs** = **GPT4All** — see `E:\AI-Offline\`.

---

## What's on this drive

| Folder | What it is | How to open | Guide |
|---|---|---|---|
| `AI-Offline\` | Offline AI chat (3 models, CPU + GPU) | Double-click a `CHAT-*.bat` | `AI-Offline\HOW-TO-RUN-OFFLINE-AI.html` |
| `AI-Offline\DocReader-GPT4All\` | AI that reads your PDFs & answers questions | Install once, then offline | `...\HOW-TO-ASK-YOUR-DOCS.html` |
| `Manuals\` | Survival & repair manuals (Army FMs, iFixit, Appropedia, survival/water/food) | PDF→browser, ZIM→Kiwix | `Manuals\READ-ME-FIRST.html` |
| `Manuals\Radio-Communications\` | How ham/CB/shortwave radio works + emergency comms | Browser | `RADIO-GUIDE.html` |
| `Medical\` | Offline medical Wikipedia + first-aid books | ZIM→Kiwix, PDF→browser | `Medical\READ-ME-FIRST.html` |
| `Wikipedia\` | Full Wikipedia (all articles, no images) | Kiwix | — |
| `Education\` | Courses + videos (opt-in): Khan Academy archive (Kiwix) **or** Kolibri app (pick subjects) | Kiwix / Kolibri | `Education\READ-ME-FIRST.html`, `Education\HOW-TO-KOLIBRI.html` |
| `OsmAnd\` | Offline maps (your chosen region; default US) — view on **PC (no phone)** or phone | PC: `MapViewer-Desktop\VIEW-MAPS-ON-PC.bat`; phone: bundled APK | `OsmAnd\HOW-TO-VIEW-MAPS.html` |
| `Kiwix-Reader\` | The reader for all `.zim` archives | Portable app | `Kiwix-Reader\HOW-TO-USE-KIWIX.html` |
| `Phone-Apps\` | Android apps (Kiwix + OsmAnd) to port the library to a phone, offline | Sideload the APKs | `Phone-Apps\USE-ON-PHONE.html` |

---

## Quick start by need

- **I want to chat with an AI offline:** `AI-Offline\` → double-click `CHAT-3B-light.bat`.
- **I want the AI to answer from my manuals:** set up `DocReader-GPT4All` (see its guide),
  point it at `Manuals\ArmyFieldManuals` and `Medical\Manuals-PDF`, ask away.
- **I need to fix something (car/appliance/plumbing/electrical):** open Kiwix →
  `Manuals\Repair-iFixit` and `Manuals\DIY-Appropedia`.
- **Medical / first aid:** open Kiwix → `Medical\WikiMed`; or read the PDFs in
  `Medical\Manuals-PDF`; Army first aid in `Manuals\ArmyFieldManuals`.
- **Survival / water / food:** Kiwix → `Manuals\Survival-Water-Food`; plus the Army
  survival PDFs.
- **Communicate by radio:** read `Manuals\Radio-Communications\RADIO-GUIDE.html`.
- **Learn / study (courses + video):** open `Education\` in Kiwix (if you added Khan Academy
  with `-Education` / `--education`; see `Education\READ-ME-FIRST.html`).
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
| Maps on a computer | Bundled desktop viewer + portable Java (no phone needed) | ✅ `OsmAnd\MapViewer-Desktop` |
| Maps on Android | Bundled **OsmAnd~ APK** (sideload offline) | ✅ `OsmAnd\PhoneApp-Android` |
| Maps on iPhone/iPad | OsmAnd from the App Store | app store (get while online) |

Everything that needs a one-time online step (GPT4All's first run, phone apps) should be
set up **now, while you still have internet**, so the kit is fully usable offline later.

---

## ⚠️ Reminders

- Offline AIs and old manuals **can be wrong**. Verify anything safety-critical.
- Keep the drive **backed up** (a second copy on another drive/USB is wise), and run
  **CHECK-DRIVE** (`CHECK-DRIVE.bat` on Windows, `CHECK-DRIVE.command` on macOS) every few
  months to find damaged files.
- **Practice** using each tool now so it's familiar in an actual emergency.

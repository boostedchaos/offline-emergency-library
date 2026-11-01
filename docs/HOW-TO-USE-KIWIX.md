# How to Read the Offline Archives — Kiwix

Most of this library is **`.zim` files**: compressed offline copies of whole websites
(Wikipedia, medical sites, iFixit, Q&A sites, textbooks). You read them with **Kiwix**,
a free offline reader. The drive carries Kiwix for **Windows, macOS and Linux**, so
**nothing needs to be installed**.

PDF books do **not** need Kiwix; they open in any web browser.

---

## Option A — OPEN-LIBRARY (recommended, every computer)

1. In the top folder of the drive, open:
   - **Windows:** `OPEN-LIBRARY.bat`
   - **Mac:** `OPEN-LIBRARY.command` (if blocked: **System Settings → Privacy & Security → Open Anyway**)
   - **Linux:** run `bash OPEN-LIBRARY.sh` in a terminal
2. A window opens and finds every `.zim` on the drive. Your browser then opens at
   **<http://localhost:8095>**.
3. Click an archive, or use the **search box** to search its full text offline.
4. To stop, close the OPEN-LIBRARY window.

It uses `kiwix-serve` from `Kiwix-Reader/tools/<your system>/`. If the browser page is
blank, wait a few seconds and refresh.

---

## Option B — Kiwix desktop app

- **Windows:** `Kiwix-Reader/app/kiwix-desktop.exe` (portable). Use **File → Open file**
  and pick a `.zim`.
- **Linux (x64):** `Kiwix-Reader/kiwix-desktop_x86_64_*.appimage` — make it executable,
  then run it.
- **Mac:** use Option A. (The Mac desktop app comes only from the App Store.)

---

## Option C — Phones and tablets

- **Android:** install `Phone-Apps/*.apk` (Kiwix), copy `.zim` files to the phone, open
  them in the app. See `Phone-Apps/USE-ON-PHONE`.
- **iPhone/iPad:** install **Kiwix** from the App Store **while online**, then import
  `.zim` files with the Files app.

---

## Where the archives are

| Folder | Contents |
|---|---|
| `Wikipedia/` | All of English Wikipedia |
| `Medical/` | Medical library, military medicine, CDC, NHS medicines, MedlinePlus, textbooks |
| `Manuals/Repair-iFixit/`, `Manuals/DIY-Appropedia/`, `Manuals/DIY-Repair/` | Repair and DIY |
| `Manuals/Survival-Water-Food/`, `Manuals/Survival-Videos/` | Survival, water, food, knots, prepping |
| `Manuals/Food-Garden/` | Cooking, gardening, homesteading |
| `Manuals/Radio-Communications/` | Amateur radio Q&A |
| `Education/` | Wikibooks, Wikiversity, LibreTexts, TED |
| `Computing/` | Programming docs, electronics Q&A |

---

## Notes

- **Fully offline.** Kiwix and the `.zim` files need no internet.
- `.zim` files are **already compressed**. Don't unzip them; open them directly.
- For AI answers from your **PDFs**, use **GPT4All** (see
  `AI-Offline/DocReader-GPT4All/HOW-TO-ASK-YOUR-DOCS`). Kiwix is for browsing and
  searching the archives.

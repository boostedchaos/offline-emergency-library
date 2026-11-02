# How to Read the Offline Archives — Kiwix

Several parts of this kit are **`.zim` files** — compressed offline copies of entire
websites (Wikipedia-medicine, iFixit repair guides, Appropedia DIY, survival guides).
To read a `.zim` file you use **Kiwix**, a free offline reader. This is the **only
dependency** in the whole kit, and it's **portable — no installation required**.

PDF manuals do **not** need Kiwix; they open in Edge or any browser.

---

## What needs Kiwix (the .zim files)

| File / folder | Contents |
|---|---|
| `E:\Medical\WikiMed\` | Offline medical Wikipedia (with images) |
| `E:\Medical\zimgit-medicine\` | Curated medical/first-aid guide |
| `E:\Manuals\Repair-iFixit\` | iFixit repair guides (auto, appliances, electronics, phones) |
| `E:\Manuals\DIY-Appropedia\` | DIY: plumbing, electrical, construction, energy, water, food |
| `E:\Manuals\Survival-Water-Food\` | Survival (post-disaster), water, food prep, knots |
| `E:\Wikipedia\` (if converted to ZIM) | Full Wikipedia |
| `E:\Education\KhanAcademy\` | Khan Academy courses + videos (opt-in) |

---

## Option A — Portable app (no install) — recommended

1. Open `E:\Kiwix-Reader\app\`.
2. Double-click **`kiwix-desktop.exe`**.
   (If Windows SmartScreen warns, click **More info → Run anyway**.)
3. In Kiwix: **File → Open file** (or the "Open" button), then browse to a `.zim` file,
   e.g. `E:\Medical\WikiMed\wikipedia_en_medicine_maxi_2026-10.zim`.
4. The archive opens like a website. Use the **search box** to find any article —
   it searches the full text offline.
5. Open each `.zim` the same way. You can open several; Kiwix remembers your library.

> Tip: Open every `.zim` once so they all appear in your Kiwix **Library** for quick
> access later.

---

## Option B — Read in your web browser (kiwix-serve)

If you prefer to read in Edge/Chrome, Kiwix can serve the archives locally:

1. Open a Command Prompt (Windows key → type `cmd` → Enter).
2. Run (adjust path/filename):
   ```
   "E:\Kiwix-Reader\app\kiwix-serve.exe" --port 8090 "E:\Medical\WikiMed\wikipedia_en_medicine_maxi_2026-10.zim"
   ```
   To serve several at once, list multiple `.zim` paths at the end.
3. Open a browser to **http://localhost:8090** — browse and search offline.
4. Close the Command Prompt window to stop serving.

---

## Phones / tablets (optional, for emergencies)

The **Kiwix** app is free on Android and iOS. You can copy a `.zim` file to a phone and
read it there too — handy if you need a grab-and-go medical reference. (The app itself
is downloaded from the app store while you have internet.)

---

## Notes

- **Fully offline.** Kiwix and the `.zim` files need no internet.
- `.zim` files are **already compressed** — don't unzip them; open them directly.
- For AI Q&A over your **PDFs**, use **GPT4All** instead (see
  `E:\AI-Offline\DocReader-GPT4All\HOW-TO-ASK-YOUR-DOCS`). Kiwix is for browsing and
  searching the big wiki/repair archives.

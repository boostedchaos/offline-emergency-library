# Use the Library on a Phone / Tablet

You can carry most of this library on a phone — handy for grab-and-go emergencies. The
`Phone-Apps\` folder bundles the Android apps you need so you can install them **offline**
(no Play Store, no internet). Then you copy the content files over.

| On the phone you can… | App (bundled APK) | Content to copy |
|---|---|---|
| Read all offline archives (Wikipedia, medical, repair, survival) | **Kiwix** | the `.zim` files from `Medical\`, `Manuals\...` |
| Use offline maps (navigation, search) | **OsmAnd~** | the `.obf.zip` files from `OsmAnd\` |
| Read the PDF manuals | any PDF app (built in) | PDFs from `Manuals\`, `Medical\` |
| Read these HTML guides | any browser (built in) | the `.html` files |

---

## Android — step by step

### 1. Install the apps (offline)
1. Copy the APK files from `Phone-Apps\` to your phone (USB cable, SD card, etc.):
   - `*-universal-standalone.apk` → **Kiwix**
   - `OsmAnd-*.apk` → **OsmAnd**
2. On the phone, tap each APK to install. The first time, Android asks you to allow
   **"Install unknown apps"** for your file manager/browser — allow it, then install.

### 2. Copy the content
- **Kiwix:** copy the `.zim` files to the phone (anywhere, e.g. a `Kiwix` folder). Open
  Kiwix → **＋ / Open file** → pick each `.zim`. They're added to your library and are
  fully searchable offline.
- **OsmAnd:** copy the `.obf.zip` map files to the phone, then in OsmAnd use
  **Menu → Configure map / Import** (or place them in `Android/data/net.osmand.plus/files/`).
- **PDFs / HTML:** copy the folders; open with any PDF viewer or browser.

> **Storage tip:** the full set is large (Wikipedia alone is ~24 GB). Most people put a
> **subset** on the phone — e.g. medical (`WikiMed`), survival, repair, and maps for their
> region — and keep the full library on the drive. Pick what fits your phone's free space
> (a 128 GB+ phone or an SD card helps).

---

## iPhone / iPad

Apple doesn't allow installing apps from a file, so get the apps from the **App Store while
you still have internet** (do this now, as part of preparing your kit):

| App (App Store, free) | What it opens |
|---|---|
| **Kiwix** | the `.zim` archives (Wikipedia, medical, repair, survival) |
| **OsmAnd Maps** | the `.obf` offline maps |
| **PocketPal AI** (optional) | a small `.gguf` AI model — see the AI section below |

PDFs and these HTML guides open in the built-in **Files** app. Nothing else to install.

### 1. Plug in the drive
- **USB-C iPad, or iPhone 15 and newer:** plug the drive straight in.
- **Lightning iPhone:** use Apple's **Lightning to USB 3 Camera Adapter** with a charger
  plugged into the adapter. Without that extra power, a USB SSD or hard drive may not start.
- The drive shows up in **Files → Browse → Locations**.

### 2. Read the archives straight from the drive (no copying)
Kiwix opens a `.zim` where it is, so even full Wikipedia works without filling the phone.
1. Open Kiwix → **Open** → pick the drive → tap a `.zim` file.
2. Repeat for each archive you want.
3. Keep the drive plugged in while you read. Unplug it and Kiwix can't read those archives
   until you plug it back in.

### 3. Maps
OsmAnd keeps its maps **inside the phone**, so import only the region you need:
in **Files**, tap the `.obf.zip` to unzip it, then share the `.obf` file to **OsmAnd**.

### What does not work on iPhone / iPad
The launchers in this kit (`.bat`, `.sh`, `.command` — desktop reader, AI chat, map viewer)
are computer programs. iPhone and iPad can't run programs from a drive. Use those on a
computer.

---

## Can I run the AI on my phone too?

The offline **chat AI** and **document-Q&A** in this kit are built for a **computer**
(Windows). Phones *can* run small AI models, but it needs a separate mobile app:

1. Install a mobile GGUF model runner (for example, a "local LLM" app from your app store
   such as **PocketPal AI**, **ChatterUI**, or **Private AI** — install while online).
2. Copy one of the small model files from `AI-Offline\models\` (the **3B** model is best
   for phones) to the phone.
3. Load that model file in the app and chat offline.

This is optional and depends on your phone's RAM (6–8 GB+ recommended). On iPhone/iPad,
**PocketPal AI** copies the model into the phone, so you need free space for it (the 3B
model is about 2 GB). The bundled Windows AI is the primary experience; phone AI is a bonus.

---

## Summary
- **Android:** everything but the AI installs **offline** from `Phone-Apps\` (Kiwix +
  OsmAnd). Copy the `.zim`, `.obf.zip`, PDFs, and HTML you want.
- **iPhone/iPad:** install Kiwix + OsmAnd from the App Store while online. Kiwix opens the
  `.zim` files straight from the drive; maps are imported into OsmAnd.
- **AI on phone:** optional, via a separate mobile app + the small model file.

# Education — Khan Academy Offline

This folder holds **Khan Academy** as an offline archive you can browse with **no
internet** — thousands of lessons and videos across math, science, economics, history, and
more. It's great for keeping kids (or adults) learning during a long outage, or anywhere
without a connection.

It opens in the **Kiwix** reader (already bundled in `Kiwix-Reader/` — no extra software).

---

## Is it here?

Khan Academy is **opt-in** because it's **large (~168 GB with videos)** — far bigger than
the rest of the library. It is **only downloaded if you asked for it** when running the
installer.

- If you see a `.zim` file in `Education\KhanAcademy\`, it's installed — jump to "How to
  open" below.
- If this folder only has this guide, Khan Academy wasn't downloaded. See "How to add it."

---

## How to add it (re-run the installer with the education flag)

```
# Windows
./Get-OfflineLibrary.ps1 -Destination "E:\" -Education
./Get-OfflineLibrary.ps1 -Destination "E:\" -Education -EduLang es   # Spanish
# macOS / Linux
./get-offline-library.sh -d /mnt/usb --education
./get-offline-library.sh -d /mnt/usb --education --edu-lang fr       # French
```

- Languages available: **`en`** (English, default), **`es`** (Spanish), **`fr`** (French).
- **~168 GB** — make sure your drive has room (a 256 GB+ drive is recommended if you add
  this). The download is resumable; re-run the same command to continue.

---

## How to open it

1. Open the **Kiwix** reader (`Kiwix-Reader/app/`, or the Android app). See
   `Kiwix-Reader/HOW-TO-USE-KIWIX`.
2. **File → Open file**, then pick the `.zim` in `Education\KhanAcademy\`.
3. Browse or search lessons; videos play inside Kiwix — fully offline.

On a phone, copy the `.zim` to the device and open it in the **Kiwix** app (bundled APK in
`Phone-Apps/`).

---

## Notes

- Khan Academy content is free and openly licensed (CC BY-NC-SA); the offline build is made
  by the Kiwix project.
- Because it includes video, it's the single biggest item available in this kit — only add
  it if you specifically want courses/video. The text references (Wikipedia, WikiMed,
  iFixit, manuals) cover knowledge far more compactly.

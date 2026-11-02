# Offline Maps — How to View Them

This drive has **two kinds of offline US maps**. Both work with **no internet**.

| You have… | Use | Where |
|---|---|---|
| Any computer (Windows, Mac, Linux) | **Option 1 — OPEN-MAPS** (web browser) ✅ easiest | `Maps-Browser/` |
| An Android phone or tablet | **Option 3** — OsmAnd app (bundled), with search and directions | `OsmAnd/` + `Phone-Apps/` |
| An iPhone or iPad | **Option 4** — OsmAnd from the App Store (install while online) | `OsmAnd/` |

---

## Option 1 — OPEN-MAPS: street maps in your web browser (any computer)

1. In the top folder of the drive, open **OPEN-MAPS**:
   - **Windows:** `OPEN-MAPS.bat`
   - **Mac:** `OPEN-MAPS.command` (if blocked: **System Settings → Privacy & Security → Open Anyway**)
   - **Linux:** run `bash OPEN-MAPS.sh` in a terminal
2. Your browser opens at **<http://localhost:8097/viewer/>** with a map of the US.
3. Zoom with the mouse wheel or the **+ / −** buttons. Pick a state in **Go to a state**.
4. To stop, close the OPEN-MAPS window.

The web address keeps your place (zoom/latitude/longitude): bookmark it to come back.
These maps show streets, highways, towns, parks and water. They cannot plan a route —
use the phone app (Option 3) for directions.

**What is inside:** state maps from the Protomaps basemap, made by
[Project NOMAD](https://github.com/Crosstalk-Solutions/project-nomad-maps), plus a
low-detail world map; the MapLibre map viewer; and Caddy, a small web server for each
system. Map data © OpenStreetMap contributors (ODbL).

---

## Option 2 — OsmAnd desktop viewer (only on the kind of computer that built the drive)

The installer adds the OsmAndMapCreator viewer and a Java runtime **for the system it
ran on** (Windows, Mac or Linux). On any other system, use Option 1.

1. Open `OsmAnd/MapViewer-Desktop/`.
2. **Windows:** double-click **`VIEW-MAPS-ON-PC.bat`**. **macOS / Linux:** run
   **`./VIEW-MAPS-ON-PC.sh`** in a terminal in that folder.
3. The first run unzips the maps into `OsmAnd/obf/` (several minutes, about 30 GB for
   the whole US), then opens the viewer.

---

## Option 3 — On an Android phone or tablet

The app is bundled, so no app store or internet is needed.

1. Copy the OsmAnd APK from `Phone-Apps/` (e.g. `OsmAnd-XXXXXX.apk`) to the device.
   (See `Phone-Apps/USE-ON-PHONE` for the full phone setup, including Kiwix.)
2. Tap the APK to install. You may need to allow **"Install unknown apps"** for your file
   manager (Settings → Apps → special access).
3. Copy the **`.obf.zip`** map files (from `OsmAnd/`) into the OsmAnd maps folder:
   usually `Android/data/net.osmand.plus/files/` — or in OsmAnd use
   **Menu → Download maps → Import** and pick the files.
4. Open OsmAnd. Maps, search and **turn-by-turn directions** all work offline.

---

## Option 4 — On an iPhone or iPad ⚠️

Apple does not allow installing apps from a file. **While you still have internet,**
install **OsmAnd Maps** from the App Store. Later, import the `.obf` map files with the
Files app, or download your regions inside OsmAnd while you are online.

---

## Notes

- **Keep a paper road atlas** in the lockbox too — electronics fail.
- To get only some states (smaller drive), run the installer with
  `--map-regions texas,"new mexico"` (Windows: `-MapRegions texas,'new mexico'`).

# Offline Maps — How to View Them (PC or Phone)

The `OsmAnd\` folder contains offline maps (`.obf.zip` files) for the **region you chose at
download time** (the default is the **United States**). You can use them **on a computer
(no phone needed)** or **on a phone/tablet**. The OffRoad desktop viewer, browser maps and
the phone app work with **no internet**; the older OsmAndMapCreator viewer (Option 1) needs
internet on Windows and macOS. Dependencies for each are bundled or explained below.

---

## OffRoad desktop viewer - recommended on a computer (any region, no internet)

The `OsmAnd\MapViewer-Desktop\` folder includes **OffRoad**, a desktop viewer that reads the same
OsmAnd `.obf` maps as the phone app. It renders them locally, so it works with **no internet**
on Windows, macOS and Linux, for **US and non-US regions**.

1. Open `OsmAnd\MapViewer-Desktop\`.
2. **Windows:** double-click **`VIEW-MAPS-OFFLINE.bat`**.
   **macOS / Linux:** run **`./VIEW-MAPS-OFFLINE.sh`** from a terminal in that folder.
   - The **first run** unzips the map files into `OsmAnd\obf\` (this can take several minutes
     and uses extra space - see the space note below).
   - Later runs skip straight to the viewer.
3. OffRoad opens with your region's maps. Pan and zoom with the mouse. Use **Search** for a
   town or street; the search and rendering use the local map files.

**Dependencies: fully handled.** The folder includes a **portable Java runtime** (`jre\`),
OffRoad (`offroad\`), and a small world basemap. Nothing else is needed on a 64-bit PC.
The launcher sets up a private OffRoad folder and links it to `OsmAnd\obf\`, so the maps are
not copied a second time.

**Tested:** Windows 11 x64 with a current Andorra OBF file, Java 21, outbound HTTP blocked and
no network connections from the viewer; streets, buildings, parks and place names rendered.
The same Java package is bundled for macOS and Linux, but those two systems were **not
runtime-tested** for this change. OffRoad is beta software (0.6-beta2) and its project has not
released since 2021; it is [GPL-3.0](https://sourceforge.net/p/offroadosm/code/ci/master/tree/LICENSE).
If it will not start, use `VIEW-MAPS-ON-PC` on Linux or the browser maps below.

> **Space note:** the maps download as compressed `.obf.zip` (~17 GB). Desktop viewing
> needs them **unzipped** to `.obf` (~30 GB), so the first run roughly doubles the map
> space. Make sure the drive has ~30 GB free before using desktop maps. (If space is
> tight, you can delete `OsmAnd\obf\` afterward; re-running the launcher recreates it.)

---

## Street maps in a web browser - optional US street detail

Add `-BrowserMaps` (Windows) or `--browser-maps` (macOS/Linux) when you run the installer to also get
**street maps that open in any web browser**, on Windows, macOS or Linux. No app and no Java are needed.

Use this when you want extra street detail for the **US**. For any other country, use the OffRoad
viewer above; it reads the region maps already on the drive.

1. Open the `Maps-Browser\` folder.
2. **Windows:** double-click `OPEN-MAPS.bat`. **macOS / Linux:** run `bash OPEN-MAPS.sh` in a terminal.
3. Your browser opens at **http://localhost:8097/viewer/**. Zoom with the mouse wheel, or pick a state in
   **Go to a state**. To stop, close the OPEN-MAPS window.

- **US only.** These are the US state maps made by Project NOMAD (Protomaps). With `US` (the default) you get
  all 50 states (~16.5 GB). With `-Region US_texas` you get only Texas. Every drive also gets a low-detail
  world map (~0.2 GB). For other countries, use OffRoad with the OsmAnd maps below.
- **Space:** browser maps come **on top of** the OsmAnd maps, which are always downloaded with them
  (~17.8 GB for the US). A full US drive with `-BrowserMaps` needs about **34 GB for maps**.
- They show streets, towns, parks and water. They cannot plan a route; use OsmAnd for directions.
- Map data © OpenStreetMap contributors (ODbL); maps by [Project NOMAD](https://github.com/Crosstalk-Solutions/project-nomad-maps)
  (MIT) from [Protomaps](https://github.com/protomaps/basemaps); viewer [MapLibre GL JS](https://maplibre.org) (BSD-3);
  local web server [Caddy](https://caddyserver.com) (Apache-2.0).

---

## Choosing your country / region (at download time)

By default the installer downloads **US** maps. To get a different country, region, or
continent, pass `-Region` (Windows) or `--region` (macOS/Linux) when you run the installer.

```
# Windows
./Get-OfflineLibrary.ps1 -Destination "E:\" -Region France
./Get-OfflineLibrary.ps1 -Destination "E:\" -Region "Germany,Austria"
./Get-OfflineLibrary.ps1 -Destination "E:\" -Region Europe        # a whole continent
./Get-OfflineLibrary.ps1 -Destination "E:\" -Region US_texas      # one sub-region

# macOS / Linux
./get-offline-library.sh -d /mnt/usb --region Japan
./get-offline-library.sh -d /mnt/usb --region world              # everything (huge!)
```

**Don't know the exact name?** List what's available (no download):
```
# Windows
./Get-OfflineLibrary.ps1 -ListRegions                 # all countries/regions
./Get-OfflineLibrary.ps1 -ListRegions -Filter US      # sub-regions of the US
# macOS / Linux
./get-offline-library.sh --list-regions               # all countries/regions
./get-offline-library.sh --list-regions France        # sub-regions of France
```

Notes:
- Accepts a **country** (`France`, `Kenya`, `Japan`), several (`"Germany,Austria"`), a
  **continent** (`Europe`, `Africa`, `Asia`, `North-America`, `South-America`,
  `Central-America`, `Australia-Oceania`), a **sub-region** (`US_texas`,
  `Germany_bayern`), or **`world`** for everything.
- **Common names and ISO codes also work** and are translated automatically — e.g. `UK`,
  `USA`, `GBR`, `DEU`, `FRA`, `JPN`, `UAE`, `Holland`, `Czech`. Anything unrecognized is
  tried as-is, so you can always use the exact OsmAnd name from `--list-regions`.
- Big countries are split into many files — picking the country name grabs them all.
- **Size varies a lot:** US ≈ 17 GB, a small country can be under 1 GB, a whole continent
  is tens of GB, and `world` is hundreds of GB. The installer prints the size before
  downloading and warns if it's very large.
- Everything else in this kit (the desktop viewer, phone apps, guides) works with **any**
  region's maps — only the selection changes.

---

## Option 1 - Legacy OsmAndMapCreator viewer

**On Windows and macOS this viewer needs internet:** it shows online map tiles from
`tile.osmand.net`, not the maps on the drive. With no internet the map area stays **blank**
([#15](https://github.com/elhajahmadj/offline-emergency-library/issues/15)). For offline use on a
computer, use **OffRoad** above instead. On **Linux x64** the bundled build has the offline
renderer, so it can draw the maps on the drive with no internet (see **Offline on Linux x64**
below). Everything you need to launch it is bundled - **no separate install, no Java to set up.**

1. Open `OsmAnd\MapViewer-Desktop\`.
2. **Windows:** double-click **`VIEW-MAPS-ON-PC.bat`**.
   **macOS / Linux:** run **`./VIEW-MAPS-ON-PC.sh`** from a terminal in that folder.
   - The **first run** unzips the map files into `OsmAnd\obf\` (this can take several
     minutes and uses extra space — see note below), then opens the viewer.
   - Later runs skip straight to the viewer.
3. The **OsmAndMapCreator** window opens. Your maps are the `.obf` files in `OsmAnd\obf\`.
   Use the app's menus to open/browse a map, zoom, and search.

**Offline on Linux x64** (tested on Debian 13 x86_64 with no network,
[#108](https://github.com/elhajahmadj/offline-emergency-library/issues/108)):

1. If you do not see the **Offline Rendering** button at the right end of the top toolbar,
   make the window wider or maximize it. The window first opens at 800×600, which can hide it.
2. Click **Offline Rendering**.
3. In the dialog, set **Directory with binary files** to the drive's `OsmAnd/obf` folder (the
   launcher prints the full path; the default is `~/osmand`), then click **OK**.

The map then draws from the drive. Use the **+** and **-** buttons to zoom.

**Dependencies: fully handled.** This folder includes a **portable Java runtime** (`jre\`)
and the **OsmAndMapCreator** app (`app\`). Nothing else is required to launch it on a 64-bit PC.

> **Known limitation on Windows and macOS ([#15](https://github.com/elhajahmadj/offline-emergency-library/issues/15)):**
> the OsmAndMapCreator window opens, but it draws **downloaded online tiles**, not the `.obf`
> maps on the drive. The offline renderer it needs (`osmand-win-amd64.lib` on Windows,
> `osmand-mac-universal.lib` on macOS) is not in the bundled build, which only has the Linux one.
> With internet the map draws; with **no internet it is blank**. This was reproduced on Windows 11
> and macOS. **Offline on a computer, use OffRoad at the top of this guide** for any region, or
> the **Android phone/tablet** map (Option 2 below).

> **Space note:** the maps download as compressed `.obf.zip` (~17 GB). Desktop viewing
> needs them **unzipped** to `.obf` (~30 GB), so the first run roughly doubles the map
> space. Make sure the drive has ~30 GB free before using desktop maps. (If space is
> tight, you can delete `OsmAnd\obf\` afterward; re-running the `.bat` recreates it.)

---

## Option 2 — On an Android phone/tablet

No app store or internet needed — the app is bundled.

1. Copy the OsmAnd APK from `Phone-Apps\` (e.g. `OsmAnd-XXXXXX.apk`) to your Android
   device. (See `Phone-Apps\USE-ON-PHONE` for the full phone setup, including Kiwix.)
2. On the device, tap the APK to install. You may need to allow **"Install unknown apps"**
   for your file manager/browser (Settings → Apps → special access).
3. Copy the **`.obf.zip`** map files (from `OsmAnd\`) into the OsmAnd maps folder on the
   device: typically `Android/data/net.osmand.plus/files/` — or in the OsmAnd app use
   **Menu → Configure map / Download maps → Import** and point it at the files.
4. Open OsmAnd. The maps work fully offline (navigation, search, routing).

**Dependency:** the **OsmAnd app** — bundled here as the **OsmAnd~ APK** (the free,
full-featured F-Droid build), so you can install it offline.

---

## Option 3 — On an iPhone/iPad ⚠️

Apple does **not** allow installing apps offline from a file. So:

1. **While you still have internet,** install **OsmAnd Maps** from the **App Store**
   (free). Do this now as part of preparing your kit.
2. Later, import the `.obf` map files into OsmAnd on iOS (via Files / iTunes file sharing),
   or download the regions inside the OsmAnd app while you still have a connection.

This is an Apple platform limitation — there's no offline sideloading like Android.

---

## Which should I use?

| You have… | Use | Dependency status |
|---|---|---|
| A Windows PC, any region | **OffRoad** (`VIEW-MAPS-OFFLINE`) | ✅ bundled, offline, runtime-tested on Windows 11 |
| A Windows PC, extra US street detail | **Browser maps** (optional) | ✅ renders reliably; opt-in `-BrowserMaps` (US only) |
| A macOS or Linux computer | **OffRoad** (`VIEW-MAPS-OFFLINE`) | ✅ bundled; not runtime-tested in this change |
| An Android phone/tablet | **Option 2** (bundled APK) | ✅ bundled APK |
| An iPhone/iPad | **Option 3** (App Store) | ⚠️ install the app while online |

---

## Notes

- The maps are standard **OsmAnd `.obf`** vector maps — detailed roads, towns, terrain,
  and search; routing works in the phone app.
- OffRoad is the offline desktop viewer. It is beta software and its last release was in 2021;
  the bundled Java runtime and world basemap are pinned so the download stays reproducible.
- The legacy OsmAndMapCreator viewer works for finding places, roads and coordinates with
  internet on Windows and macOS; offline on those, use OffRoad or a phone.
- Keep a **paper topographic map and compass** as an ultimate backup - electronics fail.
  Print [Map and compass - navigation without a device](MAP-AND-COMPASS.html)
  and practice reading terrain, following bearings and finding direction without power.

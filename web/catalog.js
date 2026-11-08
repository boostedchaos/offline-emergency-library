// Generated from catalog.json by .github/scripts/build-catalog-js.sh — do not edit.
// A file:// page cannot fetch() local JSON, so the catalog is shipped as this script.
window.CATALOG = {
  "version": 1,
  "about": "Pieces a selection file can name: get-offline-library.sh --select <file> / Get-OfflineLibrary.ps1 -Selection <file> (#139). required: always installed. needs: other ids that must be in the same selection. gb: size in GB (1024^3 bytes) measured on a full drive, the numbers both installers' space estimate uses; null = sized at install time. presets: the guided install's size presets (#80) that include the piece; maps.gb_default_us is the US map set the preset sizes assume. CI (.github/scripts/check-catalog.sh) checks that both installers accept every id and use these numbers.",
  "pieces": [
    {"id": "core", "required": true, "needs": [], "presets": ["small", "standard", "everything"], "gb": 6.3, "label": "core (AI engine, 3B model, medical, survival, manuals, Kiwix, phone apps)", "desc": "Always included: the AI engine, a small 3B chat model, the medical and survival references, the Army manuals, the Kiwix reader and the phone apps."},
    {"id": "gpt4all-repair", "needs": [], "presets": ["standard", "everything"], "gb": 4.5, "label": "GPT4All, iFixit, Appropedia", "desc": "The GPT4All desktop AI plus the iFixit repair archive and the Appropedia DIY archive."},
    {"id": "models", "needs": ["gpt4all-repair"], "presets": ["standard", "everything"], "gb": 8.9, "label": "8B + 7B AI models", "desc": "The larger 8B and 7B chat models \u2014 smarter answers, more RAM and disk."},
    {"id": "wikipedia", "needs": ["gpt4all-repair"], "presets": ["standard", "everything"], "gb": 49.1, "label": "Wikipedia", "desc": "All of Wikipedia (no images) as a Kiwix archive \u2014 the single biggest piece."},
    {"id": "maps", "needs": [], "presets": ["small", "standard", "everything"], "gb": null, "gb_viewer": 0.5, "gb_default_us": 16.6, "label": "OsmAnd maps for the selected regions + desktop viewer (map files are sized from the OsmAnd index)", "desc": "Offline OsmAnd maps for the regions you pick, with a desktop viewer. Map file sizes are measured at install time."},
    {"id": "browser-maps", "needs": ["maps"], "presets": ["everything"], "gb": null, "gb_world_map": 0.2, "gb_all_us": 15.4, "state_share_of_osmand": 0.4, "label": "browser maps for the selected regions (US states)", "desc": "Street maps for the US states you picked, viewable in any web browser."},
    {"id": "education", "needs": [], "presets": ["everything"], "gb": 168, "label": "Khan Academy", "desc": "The full Khan Academy archive including all videos \u2014 very large (opt-in)."},
    {"id": "kolibri", "needs": [], "presets": ["everything"], "gb": null, "label": "Kolibri learning app (content is picked in the app and not counted)", "desc": "The Kolibri learning app; you choose subjects inside the app, so its size is not counted here."},
    {"id": "extra-zims", "needs": [], "presets": ["everything"], "gb": 5.8, "label": "Wikivoyage + Wikibooks", "desc": "The Wikivoyage travel guide and Wikibooks open textbooks (Kiwix)."},
    {"id": "translate", "needs": ["core"], "presets": ["everything"], "gb": 2.3, "label": "translator model", "desc": "An offline two-way text translator (a small multilingual model on the bundled AI engine)."},
    {"id": "medlineplus", "needs": [], "presets": ["everything"], "gb": 0.1, "label": "MedlinePlus health topics", "desc": "Plain-language health-topic summaries from MedlinePlus (US NLM), as one offline page."}
  ]
}
;

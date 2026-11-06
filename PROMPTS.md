# How this project came to be — the original requests

This library was assembled step by step from a series of plain-language requests. They're
recorded here so the scope and intent stay clear, and so the single-command installer
(`Get-OfflineLibrary.ps1`) can be understood as the consolidation of all of them.

1. **How many GB is the full Wikipedia library?** → Decided to include the **article-text
   dump** (compressed, ~24 GB) rather than full history/media.

2. **How many GB is the US map, compressed, for offline maps?** → Chose **OsmAnd** US
   state/region map files (~17 GB).

3. **Download OsmAnd (all US state maps) and Wikipedia article text; save to the drive.**

4. **Find a free AI model that runs on any computer (no GPU/VRAM needed); add detailed docs
   + any software needed; for internet-free emergencies.** → **llama.cpp + GGUF models**
   (Llama 3.2 3B, Llama 3.1 8B), CPU-only, with launchers and a how-to.

5. **Make the how-to docs into HTML too.**

6. **Add a model that can run on a 6 GB GPU; update docs to say we have three models.** →
   Added **Qwen2.5 7B** + the **Vulkan GPU engine**.

7. **How many GB are survival & repair manuals (Army FMs, plumbing, electrical, auto)?** →
   Decided on a **focused core kit** from legal sources (public-domain Army manuals +
   openly-licensed iFixit/Appropedia), skipping copyrighted code/brand manuals.

8. **How many GB is WikiMed / medical & first-aid?** → **WikiMed maxi** (~1.8 GB) + curated
   medical PDFs.

9. **Download the focused core kit + the recommended medical build; make sure everything is
   viewable without dependencies, and document any dependencies + install guides.** →
   PDFs/HTML need only a browser; `.zim` needs **Kiwix** (bundled portable + guide).

10. **Is there an offline model that can read these docs (PDF/text/XML/ZIM) and answer
    questions? Also add a detailed guide on how ham/CB/shortwave radio works.** →
    **GPT4All** (LocalDocs RAG over PDFs/text) + a full **radio communications guide**.

11. **Update docs on how to use GPT4All; make sure no dependencies are needed.** → GPT4All
    is self-contained (CPU, no Python/CUDA); documented the one-time online setup.

12. **Every Markdown doc should also exist as HTML.**

13. **Package all of it — every request, every download, every script — into a single skill
    / agent that downloads everything when invoked, asking only where to save. Publish as a
    GitHub repo.** → This repository.

The result: **one command, one question ("Where would you like to save these files?"), a
complete offline emergency library.**

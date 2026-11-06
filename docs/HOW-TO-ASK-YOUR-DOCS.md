# Ask Your Documents — Offline AI Q&A with GPT4All

This tool lets you **point an AI at your PDFs and text files and ask questions** — it
reads the documents and answers using what's *in them*, with citations to the source.
It runs **entirely offline on your CPU** (no internet, no graphics card required).

Example: *"According to the Army survival manual, how do I purify water?"* → it finds
the relevant pages in your PDFs and answers, showing which file/page it used.

> **Not included in a `--lite` install.** If you built this drive with `--lite` / `-Lite`,
> the GPT4All installer is not here, so you have only the plain AI chat (no source-citing
> answers). To add this tool, re-run the installer into the same drive **without** the lite
> flag, or download GPT4All from **gpt4all.io** while you still have internet.

---

## 0. Dependencies — there are (almost) none

**GPT4All is completely self-contained.** The installer bundles its own AI engine. You
do **NOT** need to install Python, CUDA, Visual C++ runtimes, or anything else. It runs
on the **CPU** of any ordinary Windows 10/11 (64-bit) computer.

The **one and only** thing that needs the internet is a **one-time setup** (downloading
a chat model and the small "embedding" model that reads your documents). **Do this now,
while you still have internet** (see Section 2). After that, it works forever offline
with zero dependencies.

> We will **reuse the AI models already in `E:\AI-Offline\models`**, so you don't have
> to download big models again.

---

## 1. Install (one time, ~2 minutes)

1. Open `E:\AI-Offline\DocReader-GPT4All\`.
2. Double-click **`gpt4all-installer-win64-v3.10.0.exe`**.
3. If Windows shows "Windows protected your PC," click **More info → Run anyway**.
4. Click through the installer (default options are fine). Launch GPT4All when done.

That's the only installation. Everything below is inside the app.

---

## 2. First-run setup — DO THIS WHILE YOU STILL HAVE INTERNET

GPT4All needs (a) a **chat model** (the "brain") and (b) an **embedding model** (reads
your docs for search). We'll reuse our models for (a) and let it fetch the tiny (b).

### 2a. Point GPT4All at the models we already downloaded
1. In GPT4All, click the **gear / Settings** (top-right) → **Application** tab.
2. Find **"Model Folder"** (or "Download path"). Set it to:
   **`E:\AI-Offline\models`**
3. Go to the **Chats** screen and open the model picker (top). You should now see our
   models, e.g. **Llama 3.2 3B Instruct** and **Meta Llama 3.1 8B Instruct**. Select
   one (3B = fast, 8B = smarter). If asked, let it load.

   *If the models don't appear:* use the **"Add Model" / "Download Models"** screen and
   download any small model it offers (e.g. Llama 3.2 3B) — this needs internet and is
   a one-time step.

### 2b. Enable the document reader (LocalDocs) — fetches the embedding model once
1. Click **LocalDocs** (left sidebar).
2. Click **"+ Add Collection"** / **"Add Docs"**.
3. The first time, GPT4All will **download a small embedding model automatically**
   (needs internet, ~tens of MB, one time only). Let it finish.

Once 2a and 2b are done, **everything works offline from now on.**

---

## 3. Point it at your manuals (create collections)

A "collection" is just a folder of documents GPT4All will read. Add the kit's folders:

1. **LocalDocs → + Add Collection.**
2. Give it a name (e.g. `Army Manuals`) and choose the folder:
   - `E:\Manuals\ArmyFieldManuals`
3. Click **Create / Add**. GPT4All **indexes** the files (progress bar). Big folders
   take a few minutes the first time; after that it's instant.
4. Repeat to add more collections, e.g.:
   - `Medical` → `E:\Medical\Manuals-PDF`
   - You can also add your own folders of PDFs/notes anytime.

**Supported file types:** PDF, plain text (`.txt`), Markdown (`.md`), Word (`.docx`),
and several code/office formats. (See Section 6 for ZIM and the Wikipedia XML.)

---

## 4. Ask questions about your documents

1. Go to **Chats** and start a new chat.
2. Make sure a **model is selected** (top) and your desired **LocalDocs collection(s)
   are toggled ON** for the chat (there's a LocalDocs button/checkbox in the chat).
3. Type your question, e.g.:
   - *"How do I treat a deep cut and stop bleeding?"*
   - *"Steps to purify water if I have no filter?"*
   - *"How do I check and replace brake pads?"* (uses the auto manual)
   - *"What knots should I know and how do I tie a bowline?"*
4. The AI answers **from your documents** and shows **sources** (which file/section it
   used) so you can open the original PDF to verify.

> Tip: Ask one clear question at a time. If an answer seems off, open the cited PDF and
> read the source — the AI can make mistakes, so verify anything safety-critical.

---

## 5. Everyday use (fully offline)

- Open GPT4All → pick a model → turn on the collection(s) you want → ask.
- **3B model** = fast on any PC. **8B model** = slower but smarter (needs ~8 GB RAM).
- No internet is used. You can be completely disconnected.

---

## 6. What about ZIM files and the Wikipedia XML?

- **ZIM files** (iFixit, Appropedia, WikiMed — in `E:\Manuals` and
  `E:\Medical`) are **not** read by GPT4All. Open those in the **Kiwix** reader
  instead (see `E:\Kiwix-Reader\HOW-TO-USE-KIWIX`). Kiwix has its own fast full-text
  search across all articles.
- **Wikipedia** (`E:\Wikipedia\...zim`) is a Kiwix archive, not a document file — read it in
  **Kiwix**, not GPT4All.
- **For AI Q&A, point GPT4All at the PDF/text folders** (`ArmyFieldManuals`,
  `Medical\Manuals-PDF`, `Radio-Communications`, and any notes you add).

So you have **two complementary tools**:
- **Kiwix** = browse & search the big wiki/repair archives (ZIM).
- **GPT4All** = ask an AI questions and get answers drawn from your PDFs.

---

## 7. Troubleshooting

- **Installer blocked by SmartScreen:** More info → Run anyway.
- **No models listed:** set Model Folder to `E:\AI-Offline\models` (Settings →
  Application), or download one small model once while online.
- **LocalDocs won't index / "embedding model" error:** this needs the one-time
  embedding-model download — do it once while online (Section 2b).
- **Slow answers:** use the **3B** model; close other programs; answers are slower on
  older CPUs but still work.
- **Answer ignores my docs:** confirm the collection is **toggled ON** in the chat and
  that indexing finished.

---

## 8. Summary

- **One install**, self-contained, **no extra dependencies**, CPU-only.
- **One-time online setup** (chat model + embedding model) — do it now.
- Reuses the models in `E:\AI-Offline\models`.
- Point it at your **PDF/text folders**, then **ask questions offline** with citations.
- Use **Kiwix** for the ZIM archives and Wikipedia.

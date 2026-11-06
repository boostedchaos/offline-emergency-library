# Manual Q&A maintenance

This is a separate reader from GPT4All. It uses the drive's existing llama.cpp
server and chat model, with keyword retrieval over downloaded text. No embedding
model, Python runtime, or internet access is needed on the finished drive.

## Why no prebuilt GPT4All collection

GPT4All v3.10.0 stores canonical document paths in `localdocs_v3.db`, under the
configured model folder. Its startup cleanup removes folders and document chunks
when those paths are unavailable. A copied database alone therefore does not
survive a different drive letter or mount point. Collection creation is an
internal Qt API, with no supported indexing command in that release.

Source inspection:
- [database.cpp](https://github.com/nomic-ai/gpt4all/blob/v3.10.0/gpt4all-chat/src/database.cpp):
  `openDatabase`, `handleDocument`, and `cleanDB`.
- [database.h](https://github.com/nomic-ai/gpt4all/blob/v3.10.0/gpt4all-chat/src/database.h):
  `LOCALDOCS_VERSION`.
- [localdocs.cpp](https://github.com/nomic-ai/gpt4all/blob/v3.10.0/gpt4all-chat/src/localdocs.cpp):
  `addFolder`.
- [embllm.cpp](https://github.com/nomic-ai/gpt4all/blob/v3.10.0/gpt4all-chat/src/embllm.cpp):
  the local embedding model is loaded from the application's resources, rather
  than fetched by the indexing function.

The fallback keeps source paths relative and does not edit a user's GPT4All
settings, collections, or chat history. The launcher builds its search index in
the browser on first opening; no manual collection setup is needed.

## Source manifest and updates

`sources.tsv` is shared by both installers. Its tab-separated fields are:
library-relative PDF path, PDF hash algorithm, PDF hash, text URL (or repository
relative `text/...`), text SHA-256, `pages` or `excerpts`, and attribution.
MD5 values for Archive PDFs identify the specific original named by Archive
metadata; they are compatibility checks, not authentication of the publisher.
Text payloads use SHA-256.

On every full or lite installation the helpers rebuild `ready.tsv` from scratch.
A missing PDF, a changed PDF hash, or an invalid text payload is excluded and
listed in `missing.txt`. Never update a hash just to silence a failure: compare
the new edition, source ancestry, extraction, and license first.

For Archive sources, follow the text file's metadata `original` chain back to
the same PDF that the installer downloads. Check both installers: PowerShell
selects the largest PDF, while Bash selects the first matching PDF. If those
choices differ, fix that selection before registering the source.

Direct medical sidecars are extracted from exact official PDFs, with form-feed
separators preserving PDF page numbers. Each starts with one `#SOURCE` line giving
the title and license, so the terms travel with the file; the reader strips that
line before splitting pages. To regenerate, place the reviewed PDFs
in a temporary folder as `usuhs.pdf`, `who-complications.pdf`, and
`who-maternal.pdf`, then run:

```
uv run doc-qa/build-medical-text.py PATH_TO_PDFS
```

This is developer tooling, not an end-user dependency. Inspect extraction
warnings, compare the quoted passages with the actual PDF pages, and update the
manifest's text hashes. A successful exit alone does not prove extraction quality.

## Attribution and licenses

The Army manuals are US government works (public domain). Archive OCR text is
derived from the same identified originals and may contain OCR errors.

Medical texts retain the attribution and terms of the original PDF:
- USUHS and Henry M. Jackson Foundation, *A Practical Guide to Prolonged Casualty
  Care* (2025), CC BY-NC-SA 4.0.
- World Health Organization, *Managing complications in pregnancy and
  childbirth: a guide for midwives and doctors*, second edition (2017), and
  *WHO recommendations on maternal health*, second edition (2025),
  CC BY-NC-SA 3.0 IGO.
- Hesperian, *Where There Is No Doctor* and *Where There Is No Dentist*: consult
  the copyright and permissions pages in the downloaded editions.

Sidecars are machine-extracted text, not a new medical edition or a clinical
review. They omit illustrations and layout. Third-party material retains its
original credit and is not relicensed by this project. Read the source PDF's
license and acknowledgements before redistributing modified text.

## Ongoing checks

Run the offline helper regression when changing the manifest or setup code,
plus the repository's syntax, launcher parity, and per-OS smoke checks.
The scheduled source check must report changed or unavailable text instead of
silently accepting a new payload. Review the direct medical editions when their
publishers update them; their current hashes deliberately reject stale sidecars.
Test source-citing answers and PDF links with the real model after a llama.cpp
or model update. Keyword search is not a substitute for clinical validation.

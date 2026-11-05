# Contributing

Thanks for helping make the Offline Emergency Library better! Contributions of all sizes
are welcome — code, docs, testing, new regions, bug reports.

## Good ways to help right now
- **Test an installer on real hardware** (especially **macOS** and **Linux** — the scripts
  are syntax-checked but need real-world runs). Report what worked / what broke.
- **Improve docs** — clarity, typos, translations of the guides.
- **Add map region aliases** (e.g. `UK` → `Great-britain`, `USA` → `US`).
- **Report broken upstream sources** (a model, ZIM, or map URL that changed).

Look for issues labeled **`good first issue`** and **`help wanted`**.

## Project layout
- `Get-OfflineLibrary.ps1` — Windows installer (PowerShell)
- `get-offline-library.sh` — macOS/Linux installer (Bash)
- `build-readme-index.ps1` — generates the root `README.html` index
- `docs/` — all guides as `.md` **and** pre-rendered `.html` (keep both in sync)
- `skills/offline-emergency-library/SKILL.md` — the Claude Code skill

## Ground rules
- **Keep the two installers in parity.** A change to one usually needs the same change in
  the other. Note in your PR if you intentionally only touched one.
- **Only free / openly-licensed / public-domain content.** No piracy, no copyrighted code
  books or brand manuals.
- **Edit `docs/*.md`, then regenerate the matching `.html`** so they stay consistent.
- **Keep line endings correct:** `.ps1`/`.bat` = CRLF, `.sh` = LF (enforced by
  `.gitattributes`).
- Keep the default behavior intact: the installer asks **only** where to save, and maps
  default to **US**.

## Before you open a PR
- `bash -n get-offline-library.sh` passes.
- PowerShell parses (`[System.Management.Automation.Language.Parser]::ParseFile(...)`).
- CI (lint + upstream link check) is green.

## Reviewing a PR

Anyone can review, and regular reviewers are welcome (see #59). The list below works the
same for people and for AI agents: go through it in order, and say in the review which
items you checked.

1. **Correctness.** Read the whole diff. Does it do what the PR says, in both installers?
   A bug fix often has copies elsewhere in the scripts; look for the same pattern.
2. **License.** Every new download or bundled text is free, openly licensed or public
   domain. The PR names the license and links the page that states it ("free to
   download" is not a license). A non-commercial license (for example CC BY-NC-SA) is
   fine when the PR says so and the docs carry the terms.
3. **Both installers.** A change to downloading or setup is in `Get-OfflineLibrary.ps1`
   **and** `get-offline-library.sh`, or the PR says why only one.
4. **Docs in `.md` and `.html`.** A changed guide changes `docs/<name>.md` **and**
   `docs/<name>.html`. A new guide is also placed by both installers and linked where
   people look for it (README, `I-NEED-TO`, the matching READ-ME-FIRST).
5. **`SHA256SUMS.txt`.** If the PR changes a file listed in `SHA256SUMS.txt`, it
   regenerates that file from the committed versions (CI fails when it is out of date):

   ```bash
   while read -r _ f; do f=${f%$'\r'}; printf '%s  %s\n' "$(git show "HEAD:$f" | sha256sum | cut -d' ' -f1)" "$f"; done < SHA256SUMS.txt > SHA256SUMS.new && mv SHA256SUMS.new SHA256SUMS.txt
   ```

   Commit the change first: the command reads `HEAD`, so with uncommitted edits it hashes
   the old file and CI fails. Then commit `SHA256SUMS.txt` (or amend). On macOS, use
   `shasum -a 256` for `sha256sum`; on Windows, run it in Git Bash (the `${f%$'\r'}` part
   makes it work when Git checked the file out with CRLF line endings). When another PR merges
   a change to the same file first, rebase and regenerate again.
6. **Link check.** A new download URL is added to `.github/scripts/check-links.sh`.
7. **Default behavior.** The installer still asks only where to save, maps still default
   to US, and anything new and large is opt-in (off by default).
8. **CHANGELOG.** A user-facing change has one entry under `[Unreleased]` (Added /
   Changed / Fixed), with credit.
9. **Evidence.** The PR says what was run, on which OS, at which commit, and what was
   **not** tested. CI is green. If you can, run it yourself and post what you ran.

**Leaving the review**
- Approve when every item is met, or the PR explains the gap.
- Request changes for a wrong result, a license problem, or a missing installer or doc half.
- Say what you did **not** check, so an approval is not read as more than it is.
- Small style points are comments, not blockers.
- One approval from someone other than the PR's author is enough to merge.

## Reporting bugs
Open an issue using the template and include your **OS**, **install method**, **region**,
and the relevant lines from the `_download.log` in your destination folder.

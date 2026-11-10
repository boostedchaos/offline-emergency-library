# Contributing

Thanks for helping make the Offline Emergency Library better! Contributions of all sizes
are welcome — code, docs, testing, new regions, bug reports.

## Good ways to help right now
- **Test an installer on real hardware** (especially **macOS** and **Linux** — the scripts
  are syntax-checked but need real-world runs). Report what worked / what broke.
- **Improve docs** — clarity, typos, translations of the guides.
- **Add map region aliases**: common names or ISO codes that should map to an OsmAnd region
  (`alias_region` in the Bash installer, `$RegionAlias` in PowerShell; keep both the same).
- **Report broken upstream sources** (a model, ZIM, or map URL that changed).

Look for issues labeled **`good first issue`** and **`help wanted`**.

## Project layout
- `Get-OfflineLibrary.ps1` — Windows installer (PowerShell)
- `get-offline-library.sh` — macOS/Linux installer (Bash)
- `build-readme-index.ps1` — generates the root `README.html` index
- `docs/` — all guides as `.md` **and** pre-rendered `.html` (keep both in sync)
- `doc-qa/` - the "Ask the manuals" reader and its source list (`sources.tsv`); see `doc-qa/README.md`
- `maps-viewer/`, `medlineplus/`, `drive/` - files the installers copy onto the drive
  (browser-map viewer, MedlinePlus page, CHECK-DRIVE)
- `catalog.json` - piece ids and sizes for `--select` / `-Selection`
- `changelog.d/` - one changelog fragment per PR (see its README)
- `.github/scripts/` - the CI checks; most run offline in seconds
- `skills/offline-emergency-library/SKILL.md` — the Claude Code skill

## Ground rules
- **Keep the two installers in parity.** A change to one usually needs the same change in
  the other. Note in your PR if you intentionally only touched one.
- **Only free / openly-licensed / public-domain content.** No piracy, no copyrighted code
  books or brand manuals.
- **Edit `docs/*.md` and make the same edit in the matching `.html`.** There is no converter:
  both files are kept by hand, so open the `.html` in a browser to check it.
- **Keep line endings correct:** `.ps1`/`.bat` = CRLF, `.sh` = LF (enforced by
  `.gitattributes`).
- Keep the default behavior intact: the installer asks **only** where to save, and maps
  default to **US**.

## Before you open a PR
- Run the offline checks from the CI lint job. Each takes seconds, so run them before you push
  rather than waiting for CI (`check-catalog.sh` and `check-regions.sh` also need PowerShell, `pwsh`):

  ```bash
  git ls-files '*.sh' '*.command' | while read -r f; do bash -n "$f"; done
  bash .github/scripts/check-consistency.sh   # manual downloads, link checks, guides agree
  bash .github/scripts/check-launchers.sh
  bash .github/scripts/check-catalog.sh
  bash .github/scripts/check-regions.sh
  bash .github/scripts/compile-changelog.sh > /dev/null
  node --test doc-qa/retrieval.test.mjs
  ```

  On a Windows checkout, `check-launchers.sh` can fail on line endings and a `grep` message
  even on `main`, because Git converts the files; trust its CI result there.
- Every PowerShell script parses (`[System.Management.Automation.Language.Parser]::ParseFile(...)`).
- A bug you can reproduce with a script gets an offline check under `.github/scripts/` (or a
  case in an existing one) that fails without your fix. Keep it to seconds and off the network;
  checks that need the internet belong in `check-links.sh`.
- CI (lint, upstream link check, and the per-OS smoke test) is green. The smoke test runs the
  installer's engine, launcher and CHECK-DRIVE code on Windows, macOS and Linux, then moves the
  folder and runs from the new path; it fails if a launcher picks an engine folder the installer
  does not fill, or any generated file names the folder it was built in.

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
5. **`SHA256SUMS.txt` is not touched.** The PR does not edit it. The
   `Update SHA256SUMS` workflow regenerates it after every merge to `main`, so PRs never
   conflict on it. (To preview locally: `bash .github/scripts/update-sha256sums.sh` after
   committing; do not commit the result.)
6. **Link check.** A new download URL is added to `.github/scripts/check-links.sh`.
   CI's `check-consistency.sh` fails if a manual is missing there or differs between the
   installers; other new downloads (models, archives, apps) still need a reviewer's eye.
7. **Default behavior.** With any flag, or with no terminal, the installer asks nothing new
   (the guided questions from #80 appear only with no flags), maps still default to US, and anything new and large is opt-in (off by default).
8. **CHANGELOG fragment.** A user-facing change adds one file in `changelog.d/` (Added /
   Changed / Fixed), starting with `- **Title.**` and ending with credit plus `PR #N`
   naming the PR it ships in, and does **not** edit `CHANGELOG.md`. See
   `changelog.d/README.md` for the name and format.
9. **Evidence.** The PR says what was run, on which OS, at which commit, and what was
   **not** tested. CI is green. If you can, run it yourself and post what you ran.
10. **Claims in docs match the code.** A size, flag, region name, folder or file name that a
    guide, the README or an installer message states is what the code does. Sizes come from
    the estimate table in the installers (`est` / `$est`). New content also gets its row in the
    README's "What you get" and License tables.
11. **Regression check.** A fix for something a script can reproduce adds or extends an
    offline check in `.github/scripts/` that fails without the fix (see "Before you open a PR").
12. **Issue links.** The PR body gives each issue its own keyword: `Closes #12, closes #34`.
    `Closes #12 and #34` closes only #12. After the merge, check that every issue it fixed is
    closed, and close any that were missed with a link to the PR.

**Leaving the review**
- Approve when every item is met, or the PR explains the gap.
- Request changes for a wrong result, a license problem, or a missing installer or doc half.
- Say what you did **not** check, so an approval is not read as more than it is.
- Small style points are comments, not blockers.
- One approval from someone other than the PR's author is enough to merge.

## Opening an issue

1. **Search first**, open and closed issues, so one problem stays in one place. If it is
   already there, add what you saw to that issue instead.
2. **Pick a template** on the New issue page. Each one adds its label for you, so the
   issue lands in the right list:

   | Template | Label it adds | Use it for |
   |---|---|---|
   | Bug report | `bug` | The installer, a launcher or a tool does the wrong thing |
   | Content suggestion | `content` | A manual, book or archive to add (link its license) |
   | Docs problem | `documentation` | A guide, the README or an installer message is wrong or unclear |
   | Test request or report | `testing` | Ask for, or report, a run on real hardware |
   | Feature request / idea | `enhancement` | A region, platform or feature that is not content |

   Questions go to Discussions, not issues. Blank issues are off, because an unlabeled issue
   is easy to miss.
3. **For a bug**, include your **OS**, **install method**, **region**, and the relevant
   lines from the `_download.log` in your destination folder.
4. **One problem per issue.** Several small problems in the same file or area can share one
   issue as a checklist; unrelated problems get their own.

**Labels.** Only people with triage access can change labels. If you think an issue is
small and well defined, or needs testers, say so in the issue and a maintainer adds it:

| Label | Meaning |
|---|---|
| `bug`, `enhancement`, `content`, `documentation`, `testing`, `accessibility`, `question` | What kind of issue it is (one per issue) |
| `good first issue` | Small, clear fix with the files named; good for a first PR |
| `help wanted` | Extra attention or testers wanted |
| `duplicate`, `invalid`, `wontfix` | Set by maintainers when closing |

Maintainers and AI agents filing issues add the type label and, where it fits,
`good first issue` or `help wanted` when they create the issue, and do not assign anyone.

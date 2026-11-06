# Changelog fragments

Do not edit `CHANGELOG.md` in a PR. Add one file here instead, so two PRs never touch the
same lines.

- Name it `<short-slug>.added.md`, `<short-slug>.changed.md` or `<short-slug>.fixed.md`
  (for example `psych-first-aid.added.md`).
- The file is one changelog bullet, written exactly as it should read in `CHANGELOG.md`:
  starts with `- `, bold title, then the description, then credit and PR number.

  ```markdown
  - **Short title.** What changed and why it matters to someone using the kit. Resolves #N.
    _[@you](https://github.com/you) - PR #N._
  ```

- Preview the result with `bash .github/scripts/compile-changelog.sh` (CI runs it too and
  fails on a badly named fragment).

At release time the maintainer runs that script, pastes the output under the new version
heading in `CHANGELOG.md`, and removes the fragments with `git rm changelog.d/*.*.md`.

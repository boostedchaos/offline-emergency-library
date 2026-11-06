- **Fresh install from a selection file: `-Selection` / `--select` (#139, milestone 1).** A new
  `catalog.json` lists the pieces a selection can name: their ids, what each one needs and the
  sizes the space estimate uses. `--select selection.json` (or `-Selection`) reads
  `{"pieces":[...],"regions":[...]}`, turns it into the existing `--lite`, `--skip-*`,
  `--region` and opt-in flags, and runs the normal install. `--check-selection` /
  `-CheckSelection` prints the result and stops. A bad file, an unknown id or a missing piece
  that another one needs stops the installer before it creates anything. A new CI check,
  `.github/scripts/check-catalog.sh`, runs every catalog id through both installers (pwsh and
  Windows PowerShell 5.1) and fails when a catalog size differs from the installers' estimate.
  No picker page yet (milestone 2). Plan by [@EnragedAntelope](https://github.com/EnragedAntelope)
  and [@elhajahmadj](https://github.com/elhajahmadj) in #139.
  _[@boostedchaos](https://github.com/boostedchaos)._

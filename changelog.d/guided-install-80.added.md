- **Guided install when no flags are given (#80).** Run either installer with no flags at a
  terminal (or double-click `install.bat` / `install.command` / `install.sh`) and it asks at
  most four questions: where to save, how much (Small = `--lite`, Standard = today's default,
  Everything = every piece in `catalog.json`; the biggest preset that fits the free space is
  preselected), which maps (Enter for the US, a region name, or `none`), and one yes/no for the
  translator, MedlinePlus, Wikivoyage and Wikibooks. The answers go through the same
  pieces-to-flags code as `--select` / `-Selection`, and the installer prints them as one
  command to reuse. Any flag, or no terminal, skips every question, so CI, docs and current
  commands do not change. `catalog.json` now lists which presets hold each piece, and
  `check-catalog.sh` checks both installers use the same presets. Plan agreed with
  [@elhajahmadj](https://github.com/elhajahmadj) and
  [@EnragedAntelope](https://github.com/EnragedAntelope) in #66. Resolves #80.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #221._

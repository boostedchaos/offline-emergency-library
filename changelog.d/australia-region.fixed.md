- **`--region Australia` (and the picker's Australia box) now gets the Australian maps.** OsmAnd
  has no `Australia_*` map; it splits Australia by state (`Australia-oceania_victoria_…`), so
  the token matched 0 maps and the install stopped with "no maps matched". `Australia` and
  `aus` now mean those 11 state and territory maps in both installers. The bash installer
  also stops reading `australia` or `oceania` as a continent (part of `australia-oceania`), so
  `--region Oceania` gets the Oceania map, as it already did in PowerShell.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #TBD._

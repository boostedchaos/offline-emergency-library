- **The bash installer no longer stops at the maps step on a map OsmAnd has deleted.** OsmAnd's
  index also lists `<deleted_map>` names; bash took them as maps, OsmAnd answered 404, and the
  run stopped with "download failed" (27 of the 99 picker regions, `US` included). Bash now
  reads `<region>` lines only, as PowerShell already did.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #232._

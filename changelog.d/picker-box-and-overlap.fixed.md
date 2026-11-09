- **The picker page keeps tree ticks when you edit the free-text box, and flags overlapping
  regions.** A tree token typed in the box (for example `US_texas`) is ticked in the tree and
  left out of the box; a later edit of the box no longer unticks it. The summary now says when a
  picked region is already inside another one (`US_texas` is inside `US`). The installers
  download each map once, so the selection file is unchanged. Fixes items 3 and 4 of #207.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #228._

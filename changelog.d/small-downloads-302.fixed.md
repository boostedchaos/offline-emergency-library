- **A `Retry-After` no longer holds the small downloads either.** Repo files, the commit lookup, the
  OsmAnd index and the manual Q&A files still left retries to curl, which waits as long as the
  server's `Retry-After` asks. Both installers now retry these themselves, 4 tries 3 seconds apart
  (6 for the manual Q&A files, as before), and a try that gets no data for a minute is cut off.
  Resolves #302.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #309._

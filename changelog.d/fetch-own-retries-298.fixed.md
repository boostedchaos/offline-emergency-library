- **A `Retry-After` no longer holds a download for hours.** For their main downloads both
  installers left retries to curl, which waits as long as the server's `Retry-After` asks (6 hours while
  gutenberg.org was down) and starts a dropped download again from where that run began. They now
  retry themselves: 11 tries, 5 seconds apart (60 after a 429), each resuming where the last one
  stopped, and a try that gets no data for 2 minutes is cut off. Refs #298.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #300._

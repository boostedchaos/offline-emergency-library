- **A server that never answers no longer holds the size check.** Before a download both
  installers ask the server for the file's size, and that request had no time limit. It is now cut
  off after 30 seconds, like the one-byte request that follows it, and a size that stays unknown is
  handled as before. Resolves #303.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #306._

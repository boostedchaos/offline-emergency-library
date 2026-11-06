- **Manual Q&A reader starts on macOS and Linux.** `start-docs.sh` / `start-docs.command`
  looked for `llama-server` directly in `engine/<platform>/`, but the macOS and Linux engine
  archives unpack into a version folder (`engine/<platform>/llama-bNNNNN/`), so the launcher
  stopped with "No such file or directory". It now finds the engine the same way the other
  launchers do. A CI fixture checks the nested layout. Fixes a gap in #144.
  _[@boostedchaos](https://github.com/boostedchaos)._

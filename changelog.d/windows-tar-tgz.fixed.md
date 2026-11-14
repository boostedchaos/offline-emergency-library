- **The Windows installer unpacks the macOS and Linux `.tar.gz` files with Windows' own `tar.exe`.**
  Run from Git Bash, plain `tar.exe` was Git's GNU tar, which read `C:\...` as a remote host
  and unpacked nothing: the macOS and Linux Caddy folders stayed empty with no warning, the
  map style was missing, and the engine step stopped with "llama-cli is not in it". The
  engine unpack now checks that every file in the archive is on disk (the exit code cannot be
  used: without admin rights Windows tar exits 1 on the engine's symlinks), and a Caddy unpack
  that fails logs a WARN. _[@boostedchaos](https://github.com/boostedchaos) - #273._

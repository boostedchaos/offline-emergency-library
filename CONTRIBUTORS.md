# Contributors

Thanks to everyone who has improved this project. ❤️

**Testing and bug reports count as contributions here** — running the installer on real
hardware and reporting what breaks is just as valuable as code, and it's credited the same
way. Credit for specific fixes is in the [CHANGELOG](CHANGELOG.md) and in the GitHub release
notes.

## People

- **[@elhajahmadj](https://github.com/elhajahmadj)** — creator and maintainer.
- **[@boostedchaos](https://github.com/boostedchaos)** (Kyle Welch) — macOS testing and
  fixes: `curl … | bash` destination prompt (`/dev/tty`), Wikipedia shipped as a
  Kiwix-readable `nopic` ZIM, and the idea for optional aria2 download acceleration.
- **[@xtalax](https://github.com/xtalax)** (Alex Jones) — Linux testing; diagnosed and
  fixed the `download.kiwix.org` → `lb.download.kiwix.org` redirect so Bash lookups
  follow `-L` and all Kiwix archives download.
- **[@EnragedAntelope](https://github.com/EnragedAntelope)** — Windows testing and bug
  reporting; found that the bundled OsmAndMapCreator desktop viewer ships only the Linux
  native renderer, so the map display is blank on Windows ([#15](https://github.com/elhajahmadj/offline-emergency-library/issues/15)).

Want to help? See [CONTRIBUTING](.github/CONTRIBUTING.md) and the open issues —
testers for the macOS/Linux installers are especially welcome.

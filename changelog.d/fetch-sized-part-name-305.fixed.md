- **A half-done download resumes when the drive path is an 8.3 short name or a relative path.**
  `Get-OfflineLibrary.ps1` compared its part file by full path, so a folder spelled another way
  (`C:\Users\DEFAUL~1\...`, `.\drive`) made it delete that part and start over. It now compares
  file names. Windows only. Resolves #305.
  _[@boostedchaos](https://github.com/boostedchaos) - PR #307._

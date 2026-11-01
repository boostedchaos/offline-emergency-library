# check-drive.ps1 - Windows version of CHECK-DRIVE. Started by CHECK-DRIVE.bat.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$sums = Join-Path $root 'SHA256SUMS.txt'
if (-not (Test-Path $sums)) { Write-Host 'SHA256SUMS.txt is missing - cannot check.'; exit 1 }
$lines = Get-Content $sums
Write-Host "Checking $($lines.Count) files. This can take 10 to 40 minutes. Only problems are printed."
$bad = 0; $i = 0
foreach ($l in $lines) {
  $i++
  if ($l -notmatch '^([0-9a-f]{64})  (.+)$') { continue }
  $want = $Matches[1]; $rel = $Matches[2] -replace '^\./', ''
  $p = Join-Path $root ($rel -replace '/', '\')
  if (-not (Test-Path -LiteralPath $p)) { Write-Host "MISSING: $rel"; $bad++; continue }
  $got = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()
  if ($got -ne $want) { Write-Host "DAMAGED: $rel"; $bad++ }
  if ($i % 200 -eq 0) { Write-Host "  ...$i of $($lines.Count)" }
}
Write-Host ''
if ($bad -eq 0) { Write-Host "RESULT: ALL $($lines.Count) FILES OK." -ForegroundColor Green; exit 0 }
Write-Host "RESULT: PROBLEM. $bad file(s) damaged or missing. Re-download them, or use your second copy." -ForegroundColor Red
exit 1

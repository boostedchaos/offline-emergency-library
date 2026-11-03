# check-drive.ps1 - Windows version of CHECK-DRIVE (double-click CHECK-DRIVE.bat).
# Checks every file against CHECKSUMS-SHA256.txt (written by the installer); prints only problems.
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$list = Join-Path $root 'CHECKSUMS-SHA256.txt'
if (-not (Test-Path -LiteralPath $list)) { Write-Host 'CHECKSUMS-SHA256.txt is missing - cannot check. Re-run the installer to create it.'; exit 1 }
# Read as UTF-8 so file names with accents or other non-English letters match.
$lines = @([System.IO.File]::ReadAllLines($list, [System.Text.Encoding]::UTF8) | Where-Object { $_ -ne '' })
Write-Host "Checking $($lines.Count) files. On a large drive this can take 10 to 60 minutes. Only problems are printed."
$bad = 0; $i = 0
foreach ($l in $lines) {
  $i++
  if ($l -notmatch '^([0-9a-f]{64})  \./(.+)$') { Write-Host "UNREADABLE LINE ${i}: $l"; $bad++; continue }
  $want = $Matches[1]; $rel = $Matches[2]
  $p = Join-Path $root ($rel -replace '/', '\')
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { Write-Host "MISSING: $rel"; $bad++; continue }
  try { $got = (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower() }
  catch { Write-Host "UNREADABLE: $rel"; $bad++; continue }
  if ($got -ne $want) { Write-Host "DAMAGED: $rel"; $bad++ }
  if ($i % 200 -eq 0) { Write-Host "  ...$i of $($lines.Count)" }
}
Write-Host ''
if ($bad -eq 0) { Write-Host "RESULT: ALL $($lines.Count) FILES OK." -ForegroundColor Green; exit 0 }
Write-Host "RESULT: PROBLEM. $bad file(s) damaged or missing. Delete each one and re-run the installer to download it again, or copy it from your second drive." -ForegroundColor Red
exit 1

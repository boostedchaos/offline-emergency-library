# Per-OS smoke test with a portability check (#69), Windows half
# (check-smoke.sh is the macOS and Linux half). No models, ZIMs or maps are downloaded.
#
# Runs the real engine, launcher, CHECK-DRIVE and checksum sections of Get-OfflineLibrary.ps1
# into a temp folder, downloading only the Windows x64 engine. The installer still picks the
# llama.cpp build the real way (a build that has the files for all 8 platforms), so a missing
# file for any OS fails the run. Then it moves the folder to a new path and, from there: scans
# every file for the old path, runs each .bat launcher with --version, and runs CHECK-DRIVE.
# Run it with Windows PowerShell 5.1 (what most Windows users have, and what CI uses). From
# PowerShell 7 the CHECK-DRIVE step fails: CHECK-DRIVE.bat starts powershell.exe, which breaks
# on the PSModulePath that PowerShell 7 passes down.
# Set GITHUB_TOKEN to avoid the API rate limit. Used by CI (smoke job).
$ErrorActionPreference = 'Continue'   # same as the installer
$ProgressPreference = 'SilentlyContinue'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Fail($m){ Write-Host "FAIL: $m"; exit 1 }

# What this computer must end up with, written down here and not read from the installer,
# so that a wrong folder name in the installer shows up as a failure.
if($env:PROCESSOR_ARCHITECTURE -ne 'AMD64'){ Fail "no expected engine for $($env:PROCESSOR_ARCHITECTURE): add it to this script" }
$Asset = 'win-cpu-x64.zip'; $WantDir = 'x64'

# ---- the installer's own code, cut out by its section markers ----
$src = [System.IO.File]::ReadAllText((Join-Path $repo 'Get-OfflineLibrary.ps1')) -replace "`r`n", "`n"
function Section($start, $end){
  $m = [regex]::Match($src, "(?ms)^($start.*?)^$end")
  if(-not $m.Success -or $m.Groups[1].Value.Length -lt 200){ Fail "section '$start' not found in Get-OfflineLibrary.ps1. Were its markers renamed?" }
  $m.Groups[1].Value
}
$engine    = Section '# =+ 1\. AI engine' '# =+ 2\. AI models'
$launchers = Section 'function WriteBat' '# =+ documentation'
$checkDrv  = Section '# CHECK-DRIVE scripts' "Log '=== Building README\.html"
$sums      = Section '# =+ drive check \(#28\)' '# =+ self-check'
# Download only this computer's engine: the build is still picked using all 8 files.
$loop = '(\$e = Join-Path \$Root ''AI-Offline\\engine''\s+foreach\(\$x in )\$LlamaAssets\.Keys(\)\{)'
if([regex]::Matches($engine, $loop).Count -ne 1){ Fail 'engine section: the download loop was not found. Was it renamed?' }
$engine = [regex]::Replace($engine, $loop, '$1$SmokeAssets$2')

# ---- the installer's helpers, replaced: Log, a plain downloader, and a token for the GitHub API ----
function Log($m){ Write-Host "  $m" }
function Fetch($url, $out){
  curl.exe -fL --retry 5 --retry-delay 5 -sS -o $out $url
  if($LASTEXITCODE -ne 0 -or -not (Test-Path $out -PathType Leaf) -or (Get-Item $out).Length -eq 0){ Fail "download failed: $url" }
}
function Invoke-RestMethod { param($Uri, $Headers = @{})
  if($env:GITHUB_TOKEN -and $Uri -like 'https://api.github.com/*'){ $Headers = @{} + $Headers; $Headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
  Microsoft.PowerShell.Utility\Invoke-RestMethod -Uri $Uri -Headers $Headers
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('oel-smoke-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$orig = Join-Path $tmp 'oel-smoke-original'; $Root = Join-Path $orig 'OfflineLibrary'
New-Item -ItemType Directory -Force (Join-Path $Root 'AI-Offline\engine') | Out-Null
try {
  $SmokeAssets = @($Asset); $Lite = $true; $Translate = $false; $scriptDir = $repo
  Write-Host "== build the drive at $Root (engine for $WantDir only)"
  . ([scriptblock]::Create($engine))
  $e = Join-Path $Root 'AI-Offline\engine'
  if(-not (Test-Path (Join-Path $e 'BUILD.txt'))){ Fail 'no llama.cpp build was picked: none of the recent releases has the files for all 8 platforms (see the engine: line above)' }
  $tag = (Get-Content (Join-Path $e 'BUILD.txt') -TotalCount 1).Trim()
  if(-not (Get-ChildItem -LiteralPath (Join-Path $e $WantDir) -Recurse -File -Filter 'llama-cli.exe' -ErrorAction SilentlyContinue)){ Fail "build $tag has no llama-cli.exe in engine\$WantDir" }
  . ([scriptblock]::Create($launchers))
  if(Get-ChildItem (Join-Path $Root 'AI-Offline') -Filter '*translat*'){ Fail 'translator files were written without -Translate' }
  # Exercise the real opt-in generator too; derive the model and prompt from production.
  . ([scriptblock]::Create(([regex]::Match($src, '(?m)^\$TrModel = .+$')).Value))
  $Translate = $true
  . ([scriptblock]::Create($launchers))
  $config = Get-Content (Join-Path $Root 'AI-Offline\translate-webui.json') -Raw | ConvertFrom-Json
  $cli = Get-Content (Join-Path $Root 'AI-Offline\TRANSLATE.bat') -Raw
  $prompt = [regex]::Match($cli, '-sys "([^"]+)"').Groups[1].Value
  $temperature = [double]([regex]::Match($cli, '--temp ([0-9.]+)').Groups[1].Value)
  if(-not $prompt -or $config.systemMessage -cne $prompt -or $config.temperature -ne $temperature){ Fail 'browser defaults differ from the CLI interpreter prompt or temperature' }
  if($config.useHuggingFaceHub -ne $false -or $config.enableDiscoverModels -ne $false){ Fail 'browser UI must not discover online models' }
  . ([scriptblock]::Create($checkDrv))
  . ([scriptblock]::Create($sums))
  if(-not (Get-ChildItem (Join-Path $Root 'AI-Offline') -Filter *.bat)){ Fail 'no .bat launcher was written' }

  Write-Host '== every engine folder a launcher uses is one the installer fills'
  $dirs = @($LlamaAssets.Values)
  $picks = @(Get-ChildItem (Join-Path $Root 'AI-Offline') -Filter *.bat | ForEach-Object { [regex]::Matches((Get-Content $_.FullName -Raw), 'engine\\([a-z0-9-]+)\\') | ForEach-Object { $_.Groups[1].Value } } | Sort-Object -Unique)
  if($picks.Count -lt 1){ Fail 'no engine folder found in the .bat launchers (launcher section changed shape?)' }
  foreach($p in $picks){ if($dirs -notcontains $p){ Fail "a launcher uses engine\$p, but the installer has no such folder (folders: $($dirs -join ' '))" }; Write-Host "  ok: $p" }

  Write-Host '== move the drive to a new path, and remove the old one'
  $newParent = Join-Path $tmp 'moved here'; $new = Join-Path $newParent 'Library copy'
  New-Item -ItemType Directory -Force $newParent | Out-Null
  Move-Item -LiteralPath $Root -Destination $new
  Remove-Item -LiteralPath $orig -Recurse -Force
  if((Test-Path $Root) -or -not (Test-Path $new)){ Fail 'could not move the folder' }

  Write-Host '== no file may name the old path'
  $latin1 = [System.Text.Encoding]::GetEncoding(28591)
  function PathHits($dir){
    Get-ChildItem -LiteralPath $dir -Recurse -File -Force | Where-Object {
      $latin1.GetString([System.IO.File]::ReadAllBytes($_.FullName)).IndexOf('oel-smoke-original', [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    } | ForEach-Object { $_.FullName }
  }
  $probe = Join-Path $new '_probe.txt'
  Set-Content -Path $probe -Value 'C:\x\oel-smoke-original\y' -Encoding ascii
  if(@(PathHits $new) -notcontains $probe){ Fail 'self-test of the path scan failed' }
  Remove-Item $probe
  $hits = @(PathHits $new)
  if($hits.Count){ Fail "these files contain the old path:`n$($hits -join "`n")" }
  Write-Host '  none'

  Write-Host '== launchers run from the new path (--version)'
  $ao = Join-Path $new 'AI-Offline'
  foreach($b in @(Get-ChildItem $ao -Filter *.bat | Where-Object { $_.Name -ne 'TRANSLATE-BROWSER.bat' })){
    # A copy that asks for --version and does not wait on 'pause'; everything else is the launcher as written.
    $t = [System.IO.File]::ReadAllText($b.FullName)
    $c = $t.Replace('.exe" -m ', '.exe" --version -m ') -replace '(?m)^pause\r?$', ''
    if($c -eq $t -or $c -notmatch '--version'){ Fail "$($b.Name): its command line is not '...exe -m ...' any more" }
    $cp = Join-Path $ao "_smoke-$($b.Name)"
    [System.IO.File]::WriteAllText($cp, $c, [System.Text.Encoding]::ASCII)
    $out = (& $cp 2>&1 | Out-String); $rc = $LASTEXITCODE
    Remove-Item $cp
    if($rc -ne 0){ Fail "$($b.Name) exited ${rc}:`n$out" }
    # Older builds print "version: 6234 (abc)", newer ones "version: 0.9.0-dev (build 12128, commit abc)".
    $v = [regex]::Match($out, "version: [^\r\n]*[^0-9]$($tag.TrimStart('b'))[^0-9][^\r\n]*").Value.Trim()
    if(-not $v){ Fail "$($b.Name) did not report build ${tag}:`n$out" }
    Write-Host "  ok: $($b.Name): $v"
  }

  Write-Host '== generated browser launcher rejects missing and invalid models without opening a browser'
  # Intercept only the browser action. Engine execution is the generated launcher's real code.
  $wrapper = Join-Path $tmp 'browser-check.ps1'
  @'
param($Launcher)
function Start-Process {
  param($FilePath,$ArgumentList,$WorkingDirectory,[switch]$NoNewWindow,[switch]$PassThru,$RedirectStandardOutput,$RedirectStandardError)
  if($FilePath -like 'http*'){ Write-Host 'UNEXPECTED_BROWSER_OPEN'; return }
  Microsoft.PowerShell.Management\Start-Process @PSBoundParameters
}
& $Launcher
exit $LASTEXITCODE
'@ | Set-Content -Path $wrapper -Encoding ascii
  $browser = Join-Path $ao 'translate-browser.ps1'
  $out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrapper $browser 2>&1 | Out-String); $rc = $LASTEXITCODE
  if($rc -ne 1 -or $out -notmatch 'Translator model missing' -or $out -match 'UNEXPECTED_BROWSER_OPEN'){ Fail "missing translator model (exit ${rc}):`n$out" }
  New-Item -ItemType Directory -Force (Join-Path $ao 'models') | Out-Null
  $model = Join-Path $ao "models\$TrModel"
  Set-Content -Path $model -Value 'not a GGUF model' -Encoding ascii
  try {
    $out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrapper $browser 2>&1 | Out-String); $rc = $LASTEXITCODE
    if($rc -ne 1 -or $out -notmatch 'Translator did not start' -or $out -match 'UNEXPECTED_BROWSER_OPEN'){ Fail "invalid translator model (exit ${rc}):`n$out" }
  } finally { Remove-Item -LiteralPath $model -Force }
  $global:LASTEXITCODE = 0

  Write-Host '== CHECK-DRIVE from the new path'
  $bat = [System.IO.File]::ReadAllText((Join-Path $new 'CHECK-DRIVE.bat')) -replace '(?m)^pause\r?$', ''
  $cp = Join-Path $new '_smoke-CHECK-DRIVE.bat'
  [System.IO.File]::WriteAllText($cp, $bat, [System.Text.Encoding]::ASCII)
  $out = (& $cp 2>&1 | Out-String); $rc = $LASTEXITCODE
  Remove-Item $cp
  if($rc -ne 0 -or $out -notmatch 'RESULT: ALL [1-9][0-9]* FILES OK'){ Fail "CHECK-DRIVE.bat failed (exit ${rc}):`n$out" }
  Write-Host "  ok: CHECK-DRIVE.bat: $(([regex]::Match($out, 'RESULT:.*')).Value.Trim())"
  Write-Host '== -Only (#74) stops with a plain message before it downloads or creates anything'
  $od = Join-Path $tmp 'only-test'
  function Chk($text, [string[]]$argv){
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'Get-OfflineLibrary.ps1') @argv 2>&1 | Out-String); $rc = $LASTEXITCODE
    if($rc -ne 1 -or $out -notlike "*$text*"){ Fail "Get-OfflineLibrary.ps1 $($argv -join ' '): expected exit 1 and '$text', got exit ${rc}:`n$out" }
    Write-Host "  ok: $($argv -join ' ')"
    $global:LASTEXITCODE = 0   # the expected exit 1 above must not become this script's exit code
  }
  Chk 'unknown piece' @('-Only','bogus','-Destination',$od)
  Chk 'cannot be combined' @('-Only','translate','-Lite','-Destination',$od)
  Chk 'no finished library' @('-Only','translate','-Destination',$od)
  if(Test-Path $od){ Fail "-Only created $od although there was no finished library there" }
  New-Item -ItemType Directory -Force (Join-Path $od 'OfflineLibrary') | Out-Null
  Set-Content -Path (Join-Path $od 'OfflineLibrary\CHECKSUMS-SHA256.txt') -Value 'x  ./a' -Encoding ascii
  Chk 'needs the AI engine' @('-Only','translate','-Destination',$od)
  if(@(Get-ChildItem -LiteralPath $od -Recurse -File).Count -ne 1){ Fail '-Only translate wrote files although the AI engine is missing' }
  Write-Host "Smoke test: OK (Windows $($env:PROCESSOR_ARCHITECTURE), llama.cpp $tag)"
}
finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

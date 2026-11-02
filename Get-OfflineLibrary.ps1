<#
  Get-OfflineLibrary.ps1
  Windows downloader for the Offline Emergency Library. Mirrors get-offline-library.sh.
  Resumable: run it again to continue or to update.

  Usage:
    .\Get-OfflineLibrary.ps1                       # asks where to save
    .\Get-OfflineLibrary.ps1 -Destination E:\      # no questions
    .\Get-OfflineLibrary.ps1 -DryRun               # check every link + total size, download nothing
  Options:
    -Wikipedia maxi|nopic|mini|none   which Wikipedia (default nopic = all articles, no images)
    -SkipGroups medicine,survival,diy,food,education,computing,pdfs
    -SkipWikipedia -SkipMaps -SkipModels (small AI model only) -SkipAI
    -MapRegions a,b  only these US states in both map types, e.g. texas,'new mexico'
    -Catalog FILE    another ZIM list (default catalog/zims.tsv)
    -Jobs N          archives downloaded at the same time (default 4; 2 with aria2)
  Faster: aria2c.exe (shipped inside Kiwix desktop, which this script downloads) fetches
  each archive in many pieces from several Kiwix mirrors at once and checks it.
#>
[CmdletBinding()]
param(
  [string]$Destination,
  [ValidateSet('maxi','nopic','mini','none')][string]$Wikipedia = 'nopic',
  [string[]]$SkipGroups = @(),
  [switch]$SkipWikipedia,
  [switch]$SkipMaps,
  [string[]]$MapRegions = @(),
  [switch]$SkipModels,
  [switch]$SkipAI,
  [string]$Catalog,
  [switch]$DryRun,
  [int]$Jobs = 0
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$RepoRaw = 'https://raw.githubusercontent.com/boostedchaos/offline-emergency-library/main'
$Kiwix   = 'https://download.kiwix.org'
$UA      = 'Mozilla/5.0'
if ($SkipWikipedia) { $Wikipedia = 'none' }
$SkipGroups = @($SkipGroups | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
# -MapRegions: OsmAnd spells states with "-" (Us_rhode-island_...), NOMAD with "_" (rhode_island_...)
$MrOsm = $null; $MrNomad = $null
$mr = @($MapRegions | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
if ($mr.Count) { $MrOsm = ($mr | ForEach-Object { $_ -replace '[ _]','-' }) -join '|'; $MrNomad = ($mr | ForEach-Object { $_ -replace '[ -]','_' }) -join '|' }

# ---------------------------------------------------------------- destination
if (-not $Destination -and -not $DryRun) {
  Write-Host ''
  Write-Host '  Offline Emergency Library installer' -ForegroundColor Cyan
  Write-Host '  -----------------------------------'
  $Destination = Read-Host 'Where would you like to save these files?'
  if (-not $Destination) { Write-Host 'No destination given. Exiting.' -ForegroundColor Red; exit 1 }
}
if (-not $Destination) { $Destination = '.' }
$Root = Join-Path $Destination 'OfflineLibrary'
$Work = Join-Path ([System.IO.Path]::GetTempPath()) ("oel-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $Work | Out-Null
if ($DryRun) { $Log = $null }
else {
  try { New-Item -ItemType Directory -Force $Root | Out-Null }
  catch { Write-Host "Cannot create $Root : $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
  $Root = (Resolve-Path -LiteralPath $Root).Path     # absolute, so relative paths in the index are right
  $Log = Join-Path $Root '_download.log'
  # one run per folder: two runs writing the same file would corrupt it
  $pidFile = Join-Path $Root '_running.pid'
  if (Test-Path $pidFile) {
    $old = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($old -and (Get-Process -Id $old -ErrorAction SilentlyContinue)) {
      Write-Host "Another download is already running into $Root (process $old). Wait for it, or close it first." -ForegroundColor Red; exit 1
    }
  }
  Set-Content -Path $pidFile -Value $PID
}
function Log($m){ $s = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m; if ($Log) { Add-Content $Log $s }; Write-Host $s }
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# ---------------------------------------------------------------- helpers
$script:Failed = New-Object System.Collections.ArrayList
$script:DryBytes = [long]0; $script:DryFiles = 0
function Bad($what,$why){ [void]$script:Failed.Add("  - ${what}: $why"); Log "  FAILED ${what}: $why" }
function GB($b){ "{0:N2} GB" -f ([double]$b / 1e9) }
function P($rel){ Join-Path $Root $rel }          # relative paths use '/', which Windows accepts
function Skipped($g){ $SkipGroups -contains $g }
function Page($url){
  $t = & curl.exe -fsL --max-time 120 --retry 3 -A $UA $url
  if ($LASTEXITCODE -ne 0) { return $null }
  return ($t -join "`n")
}
# HeadInfo URL -> @(status, length) after redirects
function HeadInfo($url){
  $h = & curl.exe -sIL --max-time 60 --retry 3 -A $UA $url
  $st = ''; $len = ''
  foreach ($l in $h) {
    if ($l -match '^HTTP/\S+\s+(\d+)') { $st = $Matches[1]; $len = '' }
    elseif ($l -match '^(?i)content-length:\s*(\d+)') { $len = $Matches[1] }
  }
  return @($st, $len)
}
function Size($p){ if (Test-Path -LiteralPath $p) { (Get-Item -LiteralPath $p).Length } else { -1 } }

# Prepare: returns $null when there is nothing to download (or dry run), else @{url;out;want}
function Prepare($url,$out){
  $name = Split-Path $out -Leaf
  $hi = HeadInfo $url
  if ($hi[0] -ne '200') { Start-Sleep 5; $hi = HeadInfo $url }
  $st = $hi[0]; $want = $hi[1]
  if ($DryRun) {
    if ($st -eq '200') { $script:DryBytes += [long]("0$want"); $script:DryFiles++; Log "  ok  $(GB ("0$want"))  $name" }
    else { Bad $name "HTTP $(if($st){$st}else{'no answer'}) for $url" }
    return $null
  }
  New-Item -ItemType Directory -Force (Split-Path $out -Parent) | Out-Null
  if (Test-Path -LiteralPath $out) {
    if (-not $want -or (Size $out) -eq [long]$want) { Log "  have $name"; return $null }
    Log "  $name has the wrong size - downloading it again"; Remove-Item -LiteralPath $out -Force
  }
  $part = "$out.part"
  if ($want -and (Test-Path -LiteralPath $part)) {
    $ps = Size $part
    if ($ps -gt [long]$want) { Remove-Item -LiteralPath $part -Force }
    elseif ($ps -eq [long]$want) { Move-Item -LiteralPath $part $out -Force; Log "  done $name"; return $null }
  }
  Log "  get  $name $(if($want){GB $want})"
  return @{ url = $url; out = $out; want = $want }
}
function Finish($job,$rc){
  $name = Split-Path $job.out -Leaf; $part = "$($job.out).part"
  if ($rc -ne 0) { Bad $name "download failed (curl exit $rc). Run the script again to resume."; return $false }
  $got = Size $part
  if ($job.want -and $got -ne [long]$job.want) { Bad $name "got $got bytes, server says $($job.want). Run again to resume."; return $false }
  Move-Item -LiteralPath $part $job.out -Force; Log "  done $name"; return $true
}
# Fetch URL OUT - resumable; fails on HTTP errors; checks size against the server.
function Fetch($url,$out){
  $job = Prepare $url $out
  if (-not $job) { return (-not $DryRun) -and (Test-Path -LiteralPath $out) -or $DryRun }
  & curl.exe -fL -C - --retry 5 --retry-delay 5 --retry-all-errors -s -A $UA -o "$out.part" $url
  return (Finish $job $LASTEXITCODE)
}
function Gh-Asset($repo,$pattern,[switch]$Latest){
  $u = if ($Latest) { "https://api.github.com/repos/$repo/releases/latest" } else { "https://api.github.com/repos/$repo/releases?per_page=20" }
  try { $r = Invoke-RestMethod $u -Headers @{'User-Agent'='oel'} } catch { return $null }
  foreach ($rel in @($r)) { $a = $rel.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1; if ($a) { return $a.browser_download_url } }
  return $null
}
# newest "<prefix>YYYY-MM.zim" in a Kiwix directory (one listing download per directory)
$script:Listings = @{}
function Latest-Zim($dirPrefix){
  $i = $dirPrefix.LastIndexOf('/'); $d = $dirPrefix.Substring(0,$i); $p = $dirPrefix.Substring($i+1)
  if (-not $script:Listings.ContainsKey($d)) { $script:Listings[$d] = Page "$Kiwix/zim/$d/" }
  $re = '(?<=["''>/])' + [regex]::Escape($p) + '[0-9]{4}-[0-9]{2}\.zim'   # whole file names only
  $names = [regex]::Matches("$($script:Listings[$d])", $re) | ForEach-Object { $_.Value } | Sort-Object -Unique
  if ($names) { return "$d/" + ($names | Select-Object -Last 1) } else { return $null }
}
# Kiwix program files are served by one slow server; its mirrors carry them too.
$script:Mirrors = $null
function Init-Mirrors {
  if ($null -ne $script:Mirrors) { return }
  $k = Latest-Zim 'other/zimgit-knots_en_'
  $m = if ($k) { Page "$Kiwix/zim/$k.meta4" } else { $null }
  $script:Mirrors = @([regex]::Matches("$m", '<url location="[a-z]+" priority="[0-9]+">([^<]+)') | ForEach-Object { $_.Groups[1].Value -replace '/zim/other/.*$','' })
}
# Fast-Mirrors: once per run, time a 4 MB piece from each mirror; keep the ones >= 1 MB/s.
# (On 2026-11-01 mirror.download.kiwix.org gave 0.07 MB/s and aria2 got stuck on it.)
$script:FastMirrors = $null
function Fast-Mirrors {
  if ($null -ne $script:FastMirrors) { return }
  Init-Mirrors
  $k = Latest-Zim 'other/zimgit-knots_en_'
  $probe = Join-Path $Work 'probe.bin'
  $fast = @()
  foreach ($b in $script:Mirrors) {
    $r = (& curl.exe -s -r 0-4194303 -m 10 -o $probe -w '%{http_code} %{speed_download}' "$b/zim/$k") -split ' '
    $sp = 0.0; if ($r.Count -ge 2 -and $r[0] -eq '206') { $sp = [double]$r[1] }
    if ($sp -ge 1000000) { $fast += $b; Log ("  mirror ok   {0:N1} MB/s  {1}" -f ($sp/1e6), $b) }
    else { Log ("  mirror slow {0:N2} MB/s  {1} (not used)" -f ($sp/1e6), $b) }
  }
  Remove-Item $probe -Force -ErrorAction SilentlyContinue
  $script:FastMirrors = if ($fast.Count) { $fast } else { $script:Mirrors }   # none fast: use them all
}
function Rel-Url($path){
  Init-Mirrors
  foreach ($b in $script:Mirrors) { if ((HeadInfo "$b/$path")[0] -eq '200') { return "$b/$path" } }
  return "$Kiwix/$path"
}
# Expand-Tgz: unpack a .tar.gz with symlinks turned into real files. exFAT has no symlinks and
# Windows tar often cannot create them, so unpack to a temp folder, replace each link with a
# copy of its target, then copy the result onto the drive.
function Expand-Tgz($file,$dest){
  $tarExe = if (Get-Command tar.exe -ErrorAction SilentlyContinue) { 'tar.exe' } else { 'tar' }
  $t = Join-Path $Work 'untar'
  if (Test-Path $t) { Remove-Item $t -Recurse -Force }
  New-Item -ItemType Directory -Force $t, $dest | Out-Null
  & $tarExe -xzf $file -C $t 2>$null
  $links = @(& $tarExe -tvzf $file | Where-Object { $_ -match '^l' -and $_ -match ' -> ' })
  for ($pass = 0; $pass -lt 5; $pass++) {          # links can point at links: repeat
    foreach ($l in $links) {
      $m = [regex]::Match($l, '\s(\S+) -> (\S+)$'); if (-not $m.Success) { continue }
      $lp = Join-Path $t $m.Groups[1].Value
      $tp = Join-Path (Split-Path $lp -Parent) $m.Groups[2].Value
      $item = Get-Item -LiteralPath $lp -Force -ErrorAction SilentlyContinue
      if ($item -and $item.LinkType) { Remove-Item -LiteralPath $lp -Force; $item = $null }
      if (-not $item -and (Test-Path -LiteralPath $tp -PathType Leaf)) { Copy-Item -LiteralPath $tp $lp }
    }
  }
  Copy-Item (Join-Path $t '*') $dest -Recurse -Force
  Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
}

# free space
if (-not $DryRun) { try { $freeGB = [math]::Round(((Get-Item $Root).PSDrive.Free)/1GB,1); Log "Destination: $Root   (free space: $freeGB GB)" } catch { Log "Destination: $Root" } }
if ($DryRun) { Log 'DRY RUN: checking every link and adding up sizes. Nothing is downloaded.' }
Log "Wikipedia: $Wikipedia   Skip groups: $(if($SkipGroups){$SkipGroups -join ','}else{'none'})"

# ================================================================ 1-2. Offline AI (every platform)
# llama.cpp builds for Windows, macOS and Linux, all from ONE build so they match. Its
# llama-server includes a chat web page that also reads PDFs (replaces GPT4All, whose last
# release was 2025-02 and cannot load current models).
$LlamaAssets = @('win-cpu-x64.zip','win-cpu-arm64.zip','win-vulkan-x64.zip','macos-arm64.tar.gz','macos-x64.tar.gz','ubuntu-x64.tar.gz','ubuntu-arm64.tar.gz','ubuntu-vulkan-x64.tar.gz')
# Models: small + medium, both Apache-2.0. File names are also used by the AI-CHAT launchers.
$Models = @(
  @{ repo = 'unsloth/Qwen3.5-4B-GGUF';            file = 'Qwen3.5-4B-Q4_K_M.gguf';        big = $false }
  @{ repo = 'google/gemma-4-12B-it-qat-q4_0-gguf'; file = 'gemma-4-12b-it-qat-q4_0.gguf';  big = $true }
)
if (-not $SkipAI) {
  Log '=== [1/9] Offline AI engine (llama.cpp) for Windows, macOS and Linux ==='
  $rels = $null; try { $rels = Invoke-RestMethod 'https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=20' -Headers @{'User-Agent'='oel'} } catch {}
  $lt = $null
  foreach ($r in @($rels)) {
    $names = @($r.assets | ForEach-Object { $_.name })
    $ok = $true; foreach ($x in $LlamaAssets) { if ($names -notcontains "llama-$($r.tag_name)-bin-$x") { $ok = $false; break } }
    if ($ok) { $lt = $r.tag_name; break }
  }
  if (-not $lt) { Bad 'llama.cpp' 'no recent build has all 8 platform files' }
  else {
    Log "llama.cpp build: $lt"
    foreach ($x in $LlamaAssets) {
      $d = $x -replace '\.(zip|tar\.gz)$',''
      $out = P "AI-Offline/engine/$x"
      if ((Fetch "https://github.com/ggml-org/llama.cpp/releases/download/$lt/llama-$lt-bin-$x" $out) -and -not $DryRun) {
        $dest = P "AI-Offline/engine/$d"
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }     # fresh unpack: no stale files from an older build
        try { if ($x -like '*.zip') { Expand-Archive $out -DestinationPath $dest -Force } else { Expand-Tgz $out $dest } }
        catch { Bad $x "could not unpack it: $($_.Exception.Message)" }
      }
    }
    if (-not $DryRun) { Set-Content -Path (P 'AI-Offline/engine/BUILD.txt') -Value $lt -Encoding ascii }
  }
  Log '=== [2/9] AI chat models (GGUF) ==='
  foreach ($m in $Models) {
    if ($SkipModels -and $m.big) { Log "model (skipped): $($m.file)"; continue }
    $u = "https://huggingface.co/$($m.repo)/resolve/main/$($m.file)"
    $out = P "AI-Offline/models/$($m.file)"
    if ((Fetch $u $out) -and -not $DryRun) {
      # Hugging Face publishes each file's SHA-256 in the x-linked-etag header (checked at the end)
      $h = (& curl.exe -sI --max-time 60 -A $UA $u | Where-Object { $_ -match '^(?i)x-linked-etag:\s*"?([0-9a-f]{64})' } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
      if ($h) { Set-Content -LiteralPath "$out.sha256" -Value "$h  $($m.file)" -Encoding ascii }
    }
  }
} else { Log '=== [1-2/9] Offline AI SKIPPED ===' }

# ================================================================ 4. readers for every platform
Log '=== [4/9] Library readers for Windows, macOS and Linux (Kiwix) ==='
$kt = Page "$Kiwix/release/kiwix-tools/"
foreach ($pl in 'win-x86_64','macos-arm64','macos-x86_64','linux-x86_64','linux-aarch64') {
  $f = [regex]::Matches("$kt", "kiwix-tools_$pl-[0-9][0-9.]*[0-9]\.(tar\.gz|zip)") | ForEach-Object { $_.Value } | Sort-Object -Unique { [version](($_ -replace "^kiwix-tools_$pl-",'') -replace '\.(tar\.gz|zip)$','') } | Select-Object -Last 1
  if (-not $f) { Bad "kiwix-tools $pl" 'not found'; continue }
  $out = P "Kiwix-Reader/tools/$f"
  if ((Fetch (Rel-Url "release/kiwix-tools/$f") $out) -and -not $DryRun) {
    $dest = P "Kiwix-Reader/tools/$pl"
    if ($f -like '*.zip') { Expand-Archive $out -DestinationPath $dest -Force } else { Expand-Tgz $out $dest }
  }
}
$kd = Page "$Kiwix/release/kiwix-desktop/"
$wz = [regex]::Matches("$kd", 'kiwix-desktop_windows_x64_[0-9][0-9.]*[0-9]\.zip') | ForEach-Object { $_.Value } | Sort-Object -Unique | Select-Object -Last 1
if ($wz) {
  $out = P "Kiwix-Reader/$wz"
  if ((Fetch (Rel-Url "release/kiwix-desktop/$wz") $out) -and -not $DryRun) {
    try { Expand-Archive $out -DestinationPath (P 'Kiwix-Reader/app') -Force } catch { Bad $wz "extract failed: $($_.Exception.Message)" }
  }
} else { Bad 'Kiwix desktop (Windows)' 'not found' }
$ai = [regex]::Matches("$kd", 'kiwix-desktop_x86_64_[0-9][0-9.]*[0-9]\.appimage') | ForEach-Object { $_.Value } | Sort-Object -Unique | Select-Object -Last 1
if ($ai) { [void](Fetch (Rel-Url "release/kiwix-desktop/$ai") (P "Kiwix-Reader/$ai")) }

# ================================================================ 5-6. ZIM archives
# aria2: one archive in many pieces from every mirror in Kiwix's .meta4 list.
# aria2 keeps "<file>.aria2" beside an unfinished file; no .aria2 = finished and hash-checked.
$Aria = $null
if (-not $DryRun) {
  $bundled = P 'Kiwix-Reader/app/aria2c.exe'      # a Windows program: use it only on Windows
  if ([System.Environment]::OSVersion.Platform -eq 'Win32NT' -and (Test-Path $bundled)) { $Aria = $bundled }
  else { $c = Get-Command aria2c -ErrorAction SilentlyContinue; if ($c) { $Aria = $c.Source } }
}
if ($Jobs -le 0) { $Jobs = if ($Aria) { 2 } else { 4 } }
if ($Aria) { Log "aria2 found: archives use many mirrors at once ($Jobs at a time)"; Log 'Testing Kiwix mirrors:'; Fast-Mirrors }
function Prepare-Aria($url,$out){
  $name = Split-Path $out -Leaf
  if ((Test-Path -LiteralPath $out) -and -not (Test-Path -LiteralPath "$out.aria2")) {
    $want = (HeadInfo $url)[1]
    if (-not $want -or (Size $out) -eq [long]$want) { Log "  have $name"; return $null }
    Log "  $name has the wrong size - downloading it again"; Remove-Item -LiteralPath $out -Force
  }
  # a curl partial from an older run is a clean start of the file: aria2 continues it
  if ((Test-Path -LiteralPath "$out.part") -and -not (Test-Path -LiteralPath $out)) { Move-Item -LiteralPath "$out.part" $out -Force }
  New-Item -ItemType Directory -Force (Split-Path $out -Parent) | Out-Null
  Fast-Mirrors
  $zpath = $url.Substring($Kiwix.Length + 1)
  $uris = @($script:FastMirrors | ForEach-Object { "$_/$zpath" }); if (-not $uris) { $uris = @($url) }
  $sum = $null; $t = Page "$url.sha256"; if ($t) { $sum = ($t -split '\s+')[0] }
  Log "  get  $name (aria2, $($uris.Count) mirrors)"
  return @{ url = $url; out = $out; aria = $true; uris = $uris; sum = $sum }
}
function Finish-Aria($job,$rc){
  $name = Split-Path $job.out -Leaf
  if ($rc -ne 0 -or (Test-Path -LiteralPath "$($job.out).aria2") -or -not (Test-Path -LiteralPath $job.out)) {
    Bad $name "aria2 stopped (exit $rc). Run the script again to resume."; return $false
  }
  Log "  done $name"; return $true
}
$zimJobs = New-Object System.Collections.ArrayList
function Add-Zim($dirPrefix,$folder,$title){
  $z = Latest-Zim $dirPrefix
  if (-not $z) { Bad $title "no file matching $dirPrefix on $Kiwix"; return }
  [void]$zimJobs.Add(@{ z = $z; folder = $folder; title = $title })
}
if ($Wikipedia -ne 'none') { Log "=== [5/9] Wikipedia ($Wikipedia) ==="; Add-Zim "wikipedia/wikipedia_en_all_$($Wikipedia)_" 'Wikipedia' "Wikipedia ($Wikipedia)" }
else { Log '=== [5/9] Wikipedia SKIPPED ===' }
Log '=== [6/9] Offline archives (Kiwix ZIM) ==='
$catText = $null
if ($Catalog) { $catText = Get-Content $Catalog -Raw -Encoding UTF8 }
elseif (Test-Path (Join-Path $ScriptDir 'catalog/zims.tsv')) { $catText = Get-Content (Join-Path $ScriptDir 'catalog/zims.tsv') -Raw -Encoding UTF8 }
else { $catText = Page "$RepoRaw/catalog/zims.tsv" }
if (-not $catText) { Bad 'catalog' 'could not read catalog/zims.tsv' }
foreach ($line in ("$catText" -split "`r?`n")) {
  if (-not $line -or $line.StartsWith('#')) { continue }
  $c = $line -split "`t"
  if ($c.Count -lt 5) { continue }
  if (Skipped $c[0]) { continue }
  if ($c[3] -eq 'dupwiki' -and ($Wikipedia -eq 'maxi' -or $Wikipedia -eq 'nopic')) { continue }
  Add-Zim $c[2] $c[1] $c[4]
}
Log "archives to get: $($zimJobs.Count)   (up to $Jobs at a time)"
# Run up to $Jobs curl downloads at once
$queue = New-Object System.Collections.Queue
foreach ($j in $zimJobs) {
  $n = Split-Path $j.z -Leaf
  Log "zim: $($j.title)"
  if ($Aria) { $prep = Prepare-Aria "$Kiwix/zim/$($j.z)" (P "$($j.folder)/$n") }
  else { $prep = Prepare "$Kiwix/zim/$($j.z)" (P "$($j.folder)/$n") }
  if ($prep) { $prep.z = $j.z; $queue.Enqueue($prep) }
}
$running = New-Object System.Collections.ArrayList
$finished = New-Object System.Collections.ArrayList
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
  while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
    $job = $queue.Dequeue()
    $proc = $null
    if ($job.aria) {
      $ck = if ($job.sum) { "--checksum=sha-256=$($job.sum) " } else { '' }
      $a = "--dir=`"$(Split-Path $job.out -Parent)`" --out=`"$(Split-Path $job.out -Leaf)`" --continue=true $ck--piece-length=4M --allow-piece-length-change=true --split=16 --max-connection-per-server=4 --min-split-size=20M --file-allocation=none --max-tries=10 --retry-wait=10 --summary-interval=0 --show-console-readout=false --console-log-level=error --download-result=hide " + (($job.uris | ForEach-Object { "`"$_`"" }) -join ' ')
      try { $proc = Start-Process -FilePath $Aria -ArgumentList $a -NoNewWindow -PassThru -ErrorAction Stop } catch { Bad (Split-Path $job.out -Leaf) "could not start aria2: $($_.Exception.Message)" }
    } else {
      $a = "-fL -C - --retry 5 --retry-delay 5 --retry-all-errors -s -A `"$UA`" -o `"$($job.out).part`" `"$($job.url)`""
      try { $proc = Start-Process -FilePath 'curl.exe' -ArgumentList $a -NoNewWindow -PassThru -ErrorAction Stop } catch { Bad (Split-Path $job.out -Leaf) "could not start curl.exe: $($_.Exception.Message)" }
    }
    if (-not $proc) { continue }      # already reported; never wait on a process that did not start
    $null = $proc.Handle     # keeps ExitCode readable after the process ends (PowerShell 5.1)
    $job.proc = $proc; [void]$running.Add($job)
  }
  Start-Sleep -Seconds 2
  foreach ($job in @($running)) {
    if ($job.proc.HasExited) {
      $running.Remove($job)
      $ok = if ($job.aria) { Finish-Aria $job $job.proc.ExitCode } else { Finish $job $job.proc.ExitCode }
      if ($ok) { [void]$finished.Add($job) }
    }
  }
}
# Kiwix's published SHA-256 for every ZIM we have (checked at the end)
if (-not $DryRun) {
  foreach ($j in $zimJobs) {
    $n = Split-Path $j.z -Leaf; $zf = P "$($j.folder)/$n"
    if ((Test-Path -LiteralPath $zf) -and -not (Test-Path -LiteralPath "$zf.aria2")) { $t = Page "$Kiwix/zim/$($j.z).sha256"; if ($t) { Set-Content -LiteralPath "$zf.sha256" -Value $t -Encoding ascii } }
  }
}

# ================================================================ 7. PDFs
if (-not (Skipped 'pdfs')) {
  Log '=== [7/9] Books (PDF) ==='
  $pdfs = @(
    @{id='fm-21-76-us-army-survival-manual';                    n='FM 21-76 Army Survival Manual.pdf'}
    @{id='fm-3-05.70-survival-2002';                            n='FM 3-05.70 Survival (2002).pdf'}
    @{id='105-page-survival-field-manual';                      n='105-Page Survival Field Manual.pdf'}
    @{id='UsArmyFirstAidManualFm4-25.11';                       n='FM 4-25.11 First Aid.pdf'}
    @{id='Survival-FirstAidForSoldiers-AFieldManual';           n='Survival and First Aid for Soldiers.pdf'}
    @{id='use-and-care-of-hand-tools-and-measuring-tools-1983'; n='TM 9-243 Use and Care of Hand Tools.pdf'}
    @{id='fm-5-426-carpentry-1995';                             n='FM 5-426 Carpentry.pdf'}
    @{id='tm-9-8000-principles-of-automotive-vehicles-1985';    n='TM 9-8000 Principles of Automotive Vehicles.pdf'}
    @{id='u-s-army-guide-to-rigging';                           n='FM 5-125 Army Guide to Rigging.pdf'}
    @{id='fm-90-3-desert-operations-1993';                      n='FM 90-3 Desert Operations.pdf'}
    @{id='tm-10-412-armed-forces-recipe-service-2003';          n='TM 10-412 Armed Forces Recipe Service.pdf'}
  )
  foreach ($p in $pdfs) {
    $meta = Page "https://archive.org/metadata/$($p.id)"
    $f = $null; try { $f = ($meta | ConvertFrom-Json).files | Where-Object { $_.name -match '\.pdf$' -and $_.name -notmatch '_text\.pdf$' } | Select-Object -First 1 } catch {}
    if ($f) { [void](Fetch "https://archive.org/download/$($p.id)/$([uri]::EscapeDataString($f.name))" (P "Manuals/ArmyFieldManuals/$($p.n)")) }
    else { Bad $p.n "no PDF in archive.org item $($p.id)" }
  }
  # Hesperian health books: from Hesperian's own page at run time (their PDF names change). One PDF per chapter.
  $hesp = 'https://languages.hesperian.org/pages/en/pdf.html'
  $hp = Page $hesp
  if (-not $hp) { Bad 'Hesperian' "could not read $hesp" }
  foreach ($b in @(@('wtnd','Where There Is No Doctor (Hesperian)'), @('dent','Where There Is No Dentist (Hesperian)'))) {
    $dir = [regex]::Matches("$hp", "uploads/pdf/en_$($b[0])_[0-9]{4}/") | ForEach-Object { $_.Value } | Sort-Object -Unique | Select-Object -Last 1
    if (-not $dir) { Bad $b[1] "not listed on $hesp"; continue }
    Log "pdf: $($b[1]) ($dir)"
    $urls = [regex]::Matches("$hp", "https://hesperian\.org/wp-content/$([regex]::Escape($dir))[^`"]+\.pdf") | ForEach-Object { $_.Value } | Select-Object -Unique
    $i = 0
    foreach ($u in $urls) { $i++; [void](Fetch $u (P ("Medical/Manuals-PDF/$($b[1])/{0:D2}-{1}" -f $i, (Split-Path $u -Leaf)))) }
  }
} else { Log '=== [7/9] PDFs SKIPPED ===' }

# ================================================================ 8. Maps
if (-not $SkipMaps) {
  Log '=== [8/9] Offline US maps (OsmAnd) ==='
  $idx = Page 'https://download.osmand.net/get_indexes'
  $us = @()
  try { $us = @(([xml]$idx).osmand_regions.region | Where-Object { $_.type -eq 'map' -and $_.name -like 'us_*' } | ForEach-Object { $_.name } | Sort-Object -Unique) } catch {}
  if ($MrOsm) { $us = @($us | Where-Object { $_ -match "^Us_($MrOsm)_" }) }
  Log "osmand: $($us.Count) US map files$(if ($MrOsm) { " (regions: $($mr -join ', '))" })"
  if ($us.Count -eq 0) { Bad 'OsmAnd maps' 'no US maps found in the OsmAnd index' }
  foreach ($fn in $us) { [void](Fetch "https://download.osmand.net/download.php?standard=yes&file=$fn" (P "OsmAnd/$fn")) }

  Log '=== [8b] Desktop map viewer (OsmAndMapCreator + portable Java) ==='
  $mvd = P 'OsmAnd/MapViewer-Desktop'
  $mc = Join-Path $mvd 'OsmAndMapCreator.zip'
  if ((Fetch 'https://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip' $mc) -and -not $DryRun) {
    try {
      Expand-Archive $mc -DestinationPath (Join-Path $mvd 'app') -Force
      if (-not (Test-Path (Join-Path $mvd 'app/OsmAndMapCreator.bat'))) {
        $inner = Get-ChildItem (Join-Path $mvd 'app') -Directory | Select-Object -First 1
        if ($inner -and (Test-Path (Join-Path $inner.FullName 'OsmAndMapCreator.bat'))) { Get-ChildItem $inner.FullName -Force | Move-Item -Destination (Join-Path $mvd 'app') -Force }
      }
    } catch { Bad 'OsmAndMapCreator' "extract failed: $($_.Exception.Message)" }
  }
  $jz = Join-Path $mvd 'jre.zip'
  if ((Fetch 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse' $jz) -and -not $DryRun) {
    try {
      $tmp = Join-Path $mvd '_jre_tmp'
      if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
      Expand-Archive $jz -DestinationPath $tmp -Force
      $jreSrc = Get-ChildItem $tmp -Directory | Select-Object -First 1
      $jreDst = Join-Path $mvd 'jre'
      if (Test-Path $jreDst) { Remove-Item $jreDst -Recurse -Force }
      if ($jreSrc) { Move-Item $jreSrc.FullName $jreDst }
      Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    } catch { Bad 'Java runtime' "extract failed: $($_.Exception.Message)" }
  }
  if (-not $DryRun) {
    $prep = @'
$ErrorActionPreference='Continue'
$maps = Split-Path -Parent $PSScriptRoot      # ...\OsmAnd
$obf  = Join-Path $maps 'obf'
New-Item -ItemType Directory -Force $obf | Out-Null
$zips = Get-ChildItem (Join-Path $maps '*.obf.zip') -ErrorAction SilentlyContinue
$i=0
foreach($z in $zips){
  $i++
  $target = Join-Path $obf ($z.Name -replace '\.zip$','')
  if(-not (Test-Path $target)){
    Write-Host ("[{0}/{1}] unzipping {2}" -f $i,$zips.Count,$z.Name)
    try{ Expand-Archive $z.FullName -DestinationPath $obf -Force }catch{ Write-Host "  failed: $($_.Exception.Message)" }
  }
}
Write-Host "Maps ready in: $obf"
'@
    Set-Content -Path (Join-Path $mvd 'prepare-maps.ps1') -Value $prep -Encoding utf8
    $mvbat = @"
@echo off
title Offline Maps on PC - OsmAndMapCreator
cd /d "%~dp0"
set "JAVA_HOME=%~dp0jre"
set "PATH=%~dp0jre\bin;%PATH%"
echo Preparing map files for desktop viewing (first run can take several minutes)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare-maps.ps1"
echo.
echo Launching the desktop map viewer...
echo In the app, your maps are the .obf files in the  OsmAnd\obf  folder.
cd /d "%~dp0app"
call OsmAndMapCreator.bat
pause
"@
    [System.IO.File]::WriteAllText((Join-Path $mvd 'VIEW-MAPS-ON-PC.bat'), ($mvbat -replace "`r?`n","`r`n"), [System.Text.Encoding]::ASCII)
  }
  # ---- browser maps: Protomaps state extracts made by Project NOMAD (MIT; map data
  # (c) OpenStreetMap contributors, ODbL), NOMAD's style/fonts/symbols, MapLibre viewer,
  # and Caddy (Apache-2.0) to serve them - OPEN-MAPS opens them in any web browser.
  Log '=== [8c] Browser maps (Project NOMAD / Protomaps) + viewer ==='
  $nm = 'https://github.com/Crosstalk-Solutions/project-nomad-maps/raw/refs/heads/master'
  $names = @()
  try { $names = @((Invoke-RestMethod 'https://api.github.com/repos/Crosstalk-Solutions/project-nomad-maps/contents/pmtiles' -Headers @{'User-Agent'='oel'}) | ForEach-Object { $_.name } | Where-Object { $_ -match '^[a-z_-]+_\d{4}-\d{2}\.pmtiles$' } | Sort-Object) } catch {}
  if ($MrNomad) { $names = @($names | Where-Object { $_ -match "^(global[a-z-]*|$MrNomad)_\d{4}-\d{2}\.pmtiles$" }) }
  # newest file per region; world map first so states draw over it
  $latest = @($names | Group-Object { $_ -replace '_\d{4}-\d{2}\.pmtiles$','' } | ForEach-Object { $_.Group | Sort-Object | Select-Object -Last 1 })
  $latest = @($latest | Where-Object { $_ -like 'global*' }) + @($latest | Where-Object { $_ -notlike 'global*' } | Sort-Object)
  Log "browser maps: $($latest.Count) map files"
  if (-not $latest.Count) { Bad 'browser maps' 'no map list from the project-nomad-maps repo' }
  $regions = @()
  foreach ($fn in $latest) {
    $out = P "Maps-Browser/pmtiles/$fn"
    if ((Fetch "$nm/pmtiles/$fn" $out) -and -not $DryRun) {
      # no published fingerprints: check the PMTiles header (the file starts with "PMTiles")
      $fs = [System.IO.File]::OpenRead($out); $buf = New-Object byte[] 7; [void]$fs.Read($buf, 0, 7); $fs.Close()
      if ([System.Text.Encoding]::ASCII.GetString($buf) -eq 'PMTiles') { $regions += $fn }
      else { Bad $fn 'not a PMTiles file - deleted it, run again'; Remove-Item -LiteralPath $out -Force }
    }
  }
  if (-not $DryRun -and $regions.Count) {
    [System.IO.File]::WriteAllText((P 'Maps-Browser/regions.json'), ('[' + (($regions | ForEach-Object { '"' + $_ + '"' }) -join ',') + "]`n"), (New-Object System.Text.UTF8Encoding($false)))
  }
  $ba = P 'Maps-Browser/base-assets.tar.gz'
  if ((Fetch "$nm/base-assets.tar.gz" $ba) -and -not $DryRun) {
    $new = P 'Maps-Browser/assets-new'
    if (Test-Path $new) { Remove-Item $new -Recurse -Force }
    try {
      Expand-Tgz $ba $new
      if (Test-Path (Join-Path $new 'tozip/nomad-base-styles.json')) {
        $old = P 'Maps-Browser/assets'; if (Test-Path $old) { Remove-Item $old -Recurse -Force }
        Move-Item (Join-Path $new 'tozip') $old; Remove-Item $new -Recurse -Force
      } else { Bad 'base-assets.tar.gz' 'could not unpack the map style and fonts' }
    } catch { Bad 'base-assets.tar.gz' $_.Exception.Message }
  }
  foreach ($u in 'maplibre-gl@4.7.1/dist/maplibre-gl.js','maplibre-gl@4.7.1/dist/maplibre-gl.css','pmtiles@4.4.0/dist/pmtiles.js') {
    [void](Fetch "https://unpkg.com/$u" (P ("Maps-Browser/viewer/lib/" + (Split-Path $u -Leaf))))
  }
  # Caddy web server for every platform (one release)
  $crel = $null; try { $crel = Invoke-RestMethod 'https://api.github.com/repos/caddyserver/caddy/releases/latest' -Headers @{'User-Agent'='oel'} } catch {}
  foreach ($ck in 'windows_amd64.zip','windows_arm64.zip','mac_arm64.tar.gz','mac_amd64.tar.gz','linux_amd64.tar.gz','linux_arm64.tar.gz') {
    $a = $null; if ($crel) { $a = $crel.assets | Where-Object { $_.name -like "*_$ck" } | Select-Object -First 1 }
    if (-not $a) { Bad "caddy $ck" 'not in the latest Caddy release'; continue }
    $dir = ($ck -replace '\.(zip|tar\.gz)$','') -replace '_','-'
    $out = P "Maps-Browser/server/$($a.name)"
    if ((Fetch $a.browser_download_url $out) -and -not $DryRun) {
      $dest = P "Maps-Browser/server/$dir"
      try { if ($ck -like '*.zip') { Expand-Archive $out -DestinationPath $dest -Force } else { Expand-Tgz $out $dest } }
      catch { Bad $a.name "could not unpack it: $($_.Exception.Message)" }
    }
  }
} else { Log '=== [8/9] Maps SKIPPED ===' }

# ================================================================ phone apps
Log '=== Phone apps (Android) ==='
$ku = Gh-Asset 'kiwix/kiwix-android' 'universal-standalone\.apk$' -Latest
if (-not $ku) { $ku = Gh-Asset 'kiwix/kiwix-android' '\.apk$' -Latest }
if ($ku) { [void](Fetch $ku (P ("Phone-Apps/" + (Split-Path $ku -Leaf)))) } else { Bad 'Kiwix Android app' 'no release asset found' }
if (-not $SkipMaps) {
  $fd = Page 'https://f-droid.org/api/v1/packages/net.osmand.plus'
  $vc = $null; try { $vc = ($fd | ConvertFrom-Json).suggestedVersionCode } catch {}
  if ($vc) { [void](Fetch "https://f-droid.org/repo/net.osmand.plus_$vc.apk" (P "Phone-Apps/OsmAnd-$vc.apk")) } else { Bad 'OsmAnd Android app' 'F-Droid did not answer' }
}

if ($DryRun) {
  Log '=== DRY RUN RESULT ==='
  Log "Files: $($script:DryFiles)   Total download: $(GB $script:DryBytes)"
  Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
  if ($script:Failed.Count -gt 0) { Log "$($script:Failed.Count) link(s) did not work:"; $script:Failed | ForEach-Object { Log $_ }; exit 1 }
  Log 'All links work.'; exit 0
}

# ================================================================ documentation + drive tools
Log '=== Documentation and drive tools ==='
function Place($repoPath,$dest){
  New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
  $local = Join-Path $ScriptDir $repoPath
  if (Test-Path $local) { $c = [System.IO.File]::ReadAllText($local) } else { $c = Page "$RepoRaw/$repoPath" }
  if ($null -eq $c) { Bad (Split-Path $repoPath -Leaf) "could not get it from $RepoRaw"; return }
  if ($dest -match '\.(bat|ps1)$') { $c = $c -replace "`r?`n","`r`n" } else { $c = $c -replace "`r`n","`n" }   # .sh/.command must stay LF
  [System.IO.File]::WriteAllText($dest, $c, (New-Object System.Text.UTF8Encoding($false)))
}
function PlaceDoc($base,$dest){ Place "docs/$base.md" "$dest.md"; Place "docs/$base.html" "$dest.html" }
PlaceDoc 'START-HERE'            (P 'START-HERE')
PlaceDoc 'HOW-TO-RUN-OFFLINE-AI' (P 'AI-Offline/HOW-TO-RUN-OFFLINE-AI')
PlaceDoc 'HOW-TO-ASK-YOUR-DOCS'  (P 'AI-Offline/HOW-TO-ASK-YOUR-DOCS')
PlaceDoc 'HOW-TO-USE-KIWIX'      (P 'Kiwix-Reader/HOW-TO-USE-KIWIX')
PlaceDoc 'Manuals-READ-ME-FIRST' (P 'Manuals/READ-ME-FIRST')
PlaceDoc 'Medical-READ-ME-FIRST' (P 'Medical/READ-ME-FIRST')
PlaceDoc 'RADIO-GUIDE'           (P 'Manuals/Radio-Communications/RADIO-GUIDE')
PlaceDoc 'HOW-TO-VIEW-MAPS'      (P 'OsmAnd/HOW-TO-VIEW-MAPS')
PlaceDoc 'USE-ON-PHONE'          (P 'Phone-Apps/USE-ON-PHONE')
foreach ($f in 'OPEN-LIBRARY.command','OPEN-LIBRARY.sh','OPEN-LIBRARY.bat','CHECK-DRIVE.command','CHECK-DRIVE.sh','CHECK-DRIVE.bat','check-drive.ps1') { Place "drive/$f" (P $f) }
if (-not $SkipAI) { foreach ($f in 'AI-CHAT.command','AI-CHAT.sh','AI-CHAT.bat') { Place "drive/$f" (P $f) } }
if (-not $SkipMaps) {
  foreach ($f in 'OPEN-MAPS.command','OPEN-MAPS.sh','OPEN-MAPS.bat') { Place "drive/$f" (P $f) }
  Place 'drive/maps/index.html' (P 'Maps-Browser/viewer/index.html')
}

# ================================================================ README index
Log '=== Building README.html (full index of everything) ==='
function Esc2($s){ $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' }
function Rel2($full){ ($full.Substring($Root.Length)).TrimStart('\','/') -replace '\\','/' }
function Nice2($name){ ($name -replace '\.[A-Za-z0-9]+$','') -replace '[-_]',' ' }
function Human2($b){ if($b -ge 1GB){"{0:N2} GB" -f ($b/1GB)}elseif($b -ge 1MB){"{0:N0} MB" -f ($b/1MB)}else{"{0:N0} KB" -f ($b/1KB)} }
$idxCss = '<style>:root{--bg:#0f1420;--card:#171f2e;--ink:#e7ecf3;--muted:#9fb0c3;--accent:#4fd1c5;--accent2:#f6ad55;--line:#273246;--code:#0b0f17}@media(prefers-color-scheme:light){:root{--bg:#f4f6fb;--card:#fff;--ink:#15202b;--muted:#56657a;--accent:#0d9488;--accent2:#b45309;--line:#e2e8f0;--code:#f1f5f9}}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.65 -apple-system,Segoe UI,Roboto,Arial,sans-serif}.wrap{max-width:1000px;margin:0 auto;padding:28px 20px 80px}h1{font-size:30px;background:linear-gradient(135deg,var(--accent),var(--accent2));-webkit-background-clip:text;background-clip:text;color:transparent}h2{font-size:21px;border-bottom:2px solid var(--line);padding-bottom:6px;margin-top:32px}a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}table{border-collapse:collapse;width:100%;margin:10px 0;font-size:14.5px}th,td{border:1px solid var(--line);padding:8px 11px;text-align:left;vertical-align:top}th{background:rgba(127,127,127,.12)}.muted{color:var(--muted);font-size:13px}.hero{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 20px;margin:14px 0}</style>'
try {
  $all   = Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '._*' }
  $htmlD = $all | Where-Object { $_.Extension -eq '.html' -and $_.Name -ne 'README.html' -and $_.FullName -notmatch '[\\/](app|MapViewer-Desktop)[\\/]' } | Sort-Object { Rel2 $_.FullName }
  $pdfs  = $all | Where-Object { $_.Extension -eq '.pdf' } | Sort-Object { Rel2 $_.FullName }
  $zims  = $all | Where-Object { $_.Extension -eq '.zim' } | Sort-Object { Rel2 $_.FullName }
  $apks  = $all | Where-Object { $_.Extension -eq '.apk' } | Sort-Object { Rel2 $_.FullName }
  $progs = $all | Where-Object { $e = $_.Extension.ToLower(); ($e -in @('.bat','.sh','.command','.appimage','.run','.dmg') -or ($e -eq '.exe' -and $_.Name -match 'installer')) -and $_.FullName -notmatch '[\\/]app[\\/]' -and ((Rel2 $_.FullName).Split('/').Count -le 3) } | Sort-Object { Rel2 $_.FullName }
  $maps  = $all | Where-Object { $_.Name -like '*.obf.zip' }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("<!DOCTYPE html><html lang=`"en`"><head><meta charset=`"utf-8`"><meta name=`"viewport`" content=`"width=device-width,initial-scale=1`"><title>Offline Emergency Library - Full Index</title>$idxCss</head><body><div class=`"wrap`">")
  [void]$sb.Append("<h1>&#128703; Offline Emergency Library &mdash; Full Index</h1>")
  [void]$sb.Append("<div class='hero'>Every guide, document, manual, archive, app and data file on this drive, with links.<br>To read the archives, run <b>OPEN-LIBRARY</b> (.bat on Windows, .command on Mac, .sh on Linux).<br><span class='muted'>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')</span></div>")
  if (Test-Path (P 'START-HERE.html')) { [void]$sb.Append("<p>&#128073; New here? Start with <a href='START-HERE.html'><b>START-HERE.html</b></a>.</p>") }
  [void]$sb.Append("<h2>&#128214; Guides &amp; Documentation</h2><table><tr><th>Guide</th><th>Folder</th><th>Open</th></tr>")
  foreach ($h in $htmlD) { $rel = Rel2 $h.FullName; $dir = Split-Path $rel -Parent; if (-not $dir) { $dir = '(root)' }; $mdRel = $rel -replace '\.html$','.md'; $mdLink = if (Test-Path (P $mdRel)) { " &middot; <a href='$mdRel'>md</a>" } else { '' }; [void]$sb.Append("<tr><td>$(Esc2 (Nice2 $h.Name))</td><td class='muted'>$dir</td><td><a href='$rel'>HTML</a>$mdLink</td></tr>") }
  [void]$sb.Append("</table>")
  if ($pdfs) { [void]$sb.Append("<h2>&#128218; Manuals &amp; Books (PDF)</h2><table><tr><th>Document</th><th>Folder</th><th>Size</th><th>Open</th></tr>"); foreach ($x in $pdfs) { $rel = Rel2 $x.FullName; [void]$sb.Append("<tr><td>$(Esc2 (Nice2 $x.Name))</td><td class='muted'>$(Split-Path $rel -Parent)</td><td>$(Human2 $x.Length)</td><td><a href='$rel'>PDF</a></td></tr>") }; [void]$sb.Append("</table>") }
  if ($zims) { [void]$sb.Append("<h2>&#127760; Offline Archives (ZIM &mdash; open with OPEN-LIBRARY or Kiwix)</h2><table><tr><th>Archive</th><th>Folder</th><th>Size</th></tr>"); foreach ($x in $zims) { $rel = Rel2 $x.FullName; [void]$sb.Append("<tr><td>$(Esc2 (Nice2 $x.Name))</td><td class='muted'>$(Split-Path $rel -Parent)</td><td>$(Human2 $x.Length)</td></tr>") }; [void]$sb.Append("</table>") }
  if ($progs) { [void]$sb.Append("<h2>&#9881; Programs &amp; Launchers</h2><table><tr><th>Item</th><th>Folder</th></tr>"); foreach ($x in $progs) { $rel = Rel2 $x.FullName; $dir = Split-Path $rel -Parent; if (-not $dir) { $dir = '(root)' }; [void]$sb.Append("<tr><td><a href='$rel'>$(Esc2 $x.Name)</a></td><td class='muted'>$dir</td></tr>") }; [void]$sb.Append("</table>") }
  if ($apks) { [void]$sb.Append("<h2>&#128241; Phone Apps (Android APK)</h2><table><tr><th>App</th><th>Folder</th><th>Size</th></tr>"); foreach ($x in $apks) { $rel = Rel2 $x.FullName; [void]$sb.Append("<tr><td><a href='$rel'>$(Esc2 $x.Name)</a></td><td class='muted'>$(Split-Path $rel -Parent)</td><td>$(Human2 $x.Length)</td></tr>") }; [void]$sb.Append("</table>") }
  if ($maps) { $sum = ($maps | Measure-Object Length -Sum).Sum; [void]$sb.Append("<h2>&#128451; Maps</h2><table><tr><th>Item</th><th>Folder</th><th>Size</th></tr><tr><td>Offline US maps - $($maps.Count) files</td><td class='muted'>OsmAnd</td><td>$(Human2 $sum)</td></tr></table>") }
  [void]$sb.Append("</div></body></html>")
  [System.IO.File]::WriteAllText((P 'README.html'), $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
} catch { Bad 'README.html' $_.Exception.Message }

# ================================================================ library list for OPEN-LIBRARY
# One kiwix-manage call writes library.xml with paths relative to it, so OPEN-LIBRARY can
# serve every archive at once on any computer (no per-start scan of 60+ big files).
Log '=== Library list for OPEN-LIBRARY (library.xml) ==='
$km = $null
if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
  $km = Get-ChildItem (P 'Kiwix-Reader/tools/win-x86_64') -Recurse -Filter 'kiwix-manage.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($km) {
  $rels = @(Get-ChildItem $Root -Recurse -File -Filter '*.zim' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '._*' -and -not (Test-Path -LiteralPath "$($_.FullName).aria2") } |
    ForEach-Object { Rel2 $_.FullName } | Sort-Object)
  $new = P 'library.xml.new'; Remove-Item $new -Force -ErrorAction SilentlyContinue
  Push-Location $Root
  try {
    $ok = $true
    for ($i = 0; $i -lt $rels.Count; $i += 20) {      # 20 per call keeps the command line short
      $chunk = $rels[$i..([math]::Min($i + 19, $rels.Count - 1))]
      & $km.FullName 'library.xml.new' 'add' @chunk *> $null
      if ($LASTEXITCODE -ne 0) { $ok = $false }
    }
  } finally { Pop-Location }
  if (-not $rels.Count) { Remove-Item (P 'library.xml') -Force -ErrorAction SilentlyContinue; Log 'library.xml: no archives, skipped' }
  elseif ($ok -and (Test-Path $new)) { Move-Item $new (P 'library.xml') -Force; Log "library.xml: $(([regex]::Matches((Get-Content (P 'library.xml') -Raw), '<book ')).Count) archives" }
  else { Remove-Item $new -Force -ErrorAction SilentlyContinue; Bad 'library.xml' 'kiwix-manage could not build it (OPEN-LIBRARY will scan the drive instead)' }
} else { Log 'library.xml: skipped (needs Windows kiwix-manage.exe)' }

# ================================================================ checksums
# One fingerprint per file, so CHECK-DRIVE can prove nothing has rotted.
# Same format on every OS: "<lowercase sha256>  ./path/with/forward/slashes".
Log '=== Fingerprinting every file (SHA256SUMS.txt) - this takes a while ==='
$skipRe = '(^|/)(\._[^/]*|\.DS_Store|_[^/]*|SHA256SUMS\.txt[^/]*|[^/]*\.part|[^/]*\.aria2|[^/]*\.sha256)$|^(\.Spotlight-V100|\.fseventsd|\.Trashes|System Volume Information)/'
$files = Get-ChildItem $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
  ForEach-Object { @{ full = $_.FullName; rel = Rel2 $_.FullName } } |
  Where-Object { $_.rel -notmatch $skipRe }
$sumsList = New-Object System.Collections.Generic.List[string]
$byRel = @{}
foreach ($f in $files) {
  try { $h = (Get-FileHash -LiteralPath $f.full -Algorithm SHA256).Hash.ToLower(); $sumsList.Add("$h  ./$($f.rel)"); $byRel["./$($f.rel)"] = $h }
  catch { Bad $f.rel "could not read it for the checksum list" }
}
# sort by path in ordinal (byte) order, like LC_ALL=C sort on Mac/Linux
$arr = $sumsList.ToArray(); $keys = @($arr | ForEach-Object { $_.Substring(66) })
[System.Array]::Sort([string[]]$keys, [string[]]$arr, [System.StringComparer]::Ordinal)
$sumsText = if ($arr.Count) { ($arr -join "`n") + "`n" } else { '' }
[System.IO.File]::WriteAllText((P 'SHA256SUMS.txt'), $sumsText, (New-Object System.Text.UTF8Encoding($false)))
Log "SHA256SUMS.txt: $($arr.Count) files"

Log "=== Checking files against their publishers' fingerprints (Kiwix, Hugging Face) ==="
$zok = 0; $znone = 0
foreach ($z in (Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { ($_.Extension -eq '.zim' -or $_.Extension -eq '.gguf') -and $_.Name -notlike '._*' })) {
  if (Test-Path -LiteralPath "$($z.FullName).aria2") { continue }   # unfinished aria2 download: already listed as a problem
  $s = "$($z.FullName).sha256"
  if (-not (Test-Path -LiteralPath $s)) { if ($z.Extension -eq '.zim') { $znone++ }; continue }
  $want = ((Get-Content -LiteralPath $s -TotalCount 1) -split '\s+')[0].ToLower()
  $got = $byRel["./$(Rel2 $z.FullName)"]
  if ($want -and $want -eq $got) { $zok++ }
  elseif ($want) { Bad $z.Name "does not match its publisher's fingerprint (damaged download). Deleted it - run the script again."; Remove-Item -LiteralPath $z.FullName -Force }
}
Log "files matching their publisher's fingerprint: $zok   (archives with no published fingerprint: $znone)"

Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (P '_running.pid') -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($script:Failed.Count -gt 0) {
  Log "=== FINISHED WITH $($script:Failed.Count) PROBLEM(S) ==="
  $script:Failed | ForEach-Object { Log $_ }
  Log 'Run the same command again. It keeps what worked and retries the rest.'
  exit 1
}
Log '=== DONE. Everything downloaded and checked. ==='
Write-Host "  Your offline library is in: $Root" -ForegroundColor Green
Write-Host '  Open README.html for a full index. Run OPEN-LIBRARY to read the archives.' -ForegroundColor Green
Write-Host '  Run CHECK-DRIVE once a year to prove nothing has rotted.' -ForegroundColor Green

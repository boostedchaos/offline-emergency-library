<#
  Get-OfflineLibrary.ps1
  One-shot downloader for the Offline Emergency Library.
  Downloads: offline AI (3 models + CPU/GPU engines), GPT4All doc-Q&A, full Wikipedia
  (article text), offline US maps (OsmAnd), survival/repair/medical archives (Kiwix ZIM),
  public-domain Army field manuals + medical PDFs, the Kiwix reader, launchers, and all
  documentation (Markdown + HTML).

  Usage:
    .\Get-OfflineLibrary.ps1                      # will ask where to save
    .\Get-OfflineLibrary.ps1 -Destination E:\     # non-interactive
  Everything is RESUMABLE: re-run to continue after an interruption.
#>
[CmdletBinding()]
param(
  [string]$Destination,
  [string]$Region = 'US',   # which country/region maps to download (default US). Examples:
                            #   -Region France   -Region "Germany,Austria"   -Region Europe
                            #   -Region US_texas   -Region world   (see -ListRegions)
  [switch]$ListRegions,     # print available map regions (optionally filtered by -Filter) and exit
  [string]$Filter,          # substring filter used with -ListRegions
  [switch]$Lite,            # quick start: 3B AI, medical/survival references and regional maps
  [switch]$SkipWikipedia,   # Wikipedia is the biggest (~49 GB ZIM); allow skipping
  [switch]$SkipMaps,        # OsmAnd maps (~17 GB for US); allow skipping
  [switch]$SkipModels,      # the large AI chat models (~11 GB)
  [switch]$Education,        # OPT-IN: add Khan Academy (Kiwix ZIM, ~168 GB with videos)
  [string]$EduLang = 'en',   # Khan Academy language: en, es, or fr
  [switch]$Kolibri,          # OPT-IN: add the Kolibri learning app (pick subjects/low-res in-app)
  [switch]$BrowserMaps,      # OPT-IN: street maps in any web browser (US states, ~16.5 GB for all of the US)
  [switch]$ExtraZims,        # OPT-IN: add Wikivoyage travel guide + Wikibooks textbooks (Kiwix ZIM, ~5.8 GB)
  [switch]$Translate,        # OPT-IN: offline translator (Qwen3 4B model on the AI engine, ~2.5 GB)
  [switch]$MedlinePlus,      # OPT-IN: MedlinePlus plain-language health topics (public domain, ~30 MB)
  [switch]$NoAria            # force curl even if aria2c is installed
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
if($Lite){ $SkipWikipedia = $true; $SkipModels = $true }
$RepoRaw = 'https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main'
$Continents = @('africa','asia','australia-oceania','centralamerica','europe','northamerica','southamerica')
# Common names / ISO codes -> OsmAnd region token (unknown input passes through unchanged)
$RegionAlias = @{
  'us'='US';'usa'='US';'america'='US';'united-states'='US'
  'uk'='Gb';'gb'='Gb';'gbr'='Gb';'britain'='Gb';'great-britain'='Gb';'england'='Gb';'united-kingdom'='Gb'
  'deu'='Germany';'ger'='Germany';'fra'='France';'esp'='Spain';'ita'='Italy'
  'nld'='Netherlands';'holland'='Netherlands';'che'='Switzerland';'swiss'='Switzerland'
  'aut'='Austria';'bel'='Belgium';'prt'='Portugal';'irl'='Ireland';'swe'='Sweden';'nor'='Norway'
  'dnk'='Denmark';'fin'='Finland';'pol'='Poland';'cze'='Czech-republic';'czech'='Czech-republic';'czechia'='Czech-republic';'grc'='Greece'
  'can'='Canada';'mex'='Mexico';'bra'='Brazil';'arg'='Argentina';'nzl'='New-zealand';'new-zealand'='New-zealand'
  'jpn'='Japan';'kor'='South-korea';'korea'='South-korea';'chn'='China';'ind'='India';'idn'='Indonesia';'rus'='Russia'
  'zaf'='South-africa';'ken'='Kenya';'egy'='Egypt';'nga'='Nigeria';'tur'='Turkey';'turkiye'='Turkey'
  'sau'='Saudi-arabia';'saudi'='Saudi-arabia';'are'='United-arab-emirates';'uae'='United-arab-emirates'
}
function Resolve-RegionToken($t){ $k=$t.ToLower(); if($RegionAlias.ContainsKey($k)){ $RegionAlias[$k] } else { $t } }

# ---------------------------------------------------------------- -ListRegions (discovery, no download)
if($ListRegions){
  $tmp = Join-Path $env:TEMP 'osmand_idx.xml'
  curl.exe -sL 'https://download.osmand.net/get_indexes' -o $tmp
  try { [xml]$ix = Get-Content $tmp } catch { Write-Host "Could not fetch the OsmAnd region index."; return }
  $maps = $ix.osmand_regions.region | Where-Object { $_.type -eq 'map' }
  if($Filter){
    Write-Host "Regions / sub-regions matching '$Filter' (pass any of these to -Region):"
    $rx = '_(' + ($Continents -join '|') + ')_\d+\.obf\.zip$'
    $maps | Where-Object { $_.name -match [regex]::Escape($Filter) } | ForEach-Object { $_.name -replace $rx,'' } | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
  } else {
    Write-Host "Available top-level regions (pass one to -Region, e.g. -Region France):"
    $maps | ForEach-Object { ($_.name -split '_')[0] } | Group-Object | Sort-Object Name | ForEach-Object { Write-Host ("  {0,-26} {1} file(s)" -f $_.Name, $_.Count) }
    Write-Host ""
    Write-Host "Continents: $($Continents -join ', '), or 'world' for everything."
    Write-Host "To see a country's sub-regions:  -ListRegions -Filter US"
  }
  return
}

# ---------------------------------------------------------------- destination
if($Lite -and -not $SkipMaps){
  Write-Host "LITE MAP SIZE: maps for '$Region' are still included. The default US maps alone are about 17 GB." -ForegroundColor Yellow
  Write-Host '  Keep all US maps: use -Lite with no -Region (the default).'
  Write-Host '  Smaller area: use -Lite -Region US_delaware (example); sizes vary by region.'
  Write-Host '  No maps, viewer or OsmAnd app: use -Lite -SkipMaps.'
  Write-Host '  List available US sub-regions: run with -ListRegions -Filter US (then exit).'
  Write-Host '  To change this selection, cancel with Ctrl+C and re-run with the flags above.'
}
if (-not $Destination) {
  Write-Host ''
  Write-Host '  Offline Emergency Library installer' -ForegroundColor Cyan
  Write-Host '  -----------------------------------'
  $Destination = Read-Host 'Where would you like to save these files?'
}
if (-not $Destination) { Write-Host 'No destination given. Exiting.' -ForegroundColor Red; return }
$Root = Join-Path $Destination 'OfflineLibrary'
try { New-Item -ItemType Directory -Force $Root | Out-Null }
catch { Write-Host "Cannot create $Root : $($_.Exception.Message)" -ForegroundColor Red; return }

$Log = Join-Path $Root '_download.log'
function Log($m){ $s = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m; Add-Content $Log $s; Write-Host $s }
# Use aria2 (multi-connection, resumable) when present for a big speed-up; curl fallback.
$UseAria = (-not $NoAria) -and [bool](Get-Command aria2c -ErrorAction SilentlyContinue)
# Show a live progress meter (percent/size/speed/ETA) only when attached to a real
# console; stay quiet when output is redirected (CI/logging) so it doesn't fill with bars.
$DlTty = -not [Console]::IsOutputRedirected
function Fetch($url,$out){
  if($UseAria){
    $ariaProg = if($DlTty){ '--summary-interval=1' } else { '--summary-interval=0' }
    aria2c -c -x16 -s16 -k1M --max-tries=10 --retry-wait=5 --console-log-level=warn $ariaProg --follow-metalink=mem --allow-overwrite=false --auto-file-renaming=false -d (Split-Path $out -Parent) -o (Split-Path $out -Leaf) $url
    if($LASTEXITCODE -eq 0){ return }
    # Stop, do not fall back to curl, on Ctrl+C (aria2 exit 7) or when aria2 left a
    # part-done file: it is preallocated with gaps, so 'curl -C -' would keep a corrupt
    # copy. aria2 resumes it from its .aria2 control file on the next run.
    if($LASTEXITCODE -eq 7 -or (Test-Path "$out.aria2")){
      Log "ERROR: download stopped: $url -> $out. Re-run the installer to resume."
      exit 1
    }
    Log '  (aria2 failed, falling back to curl)'
  }
  $curlProg = if($DlTty){ '-#' } else { '-sS' }
  curl.exe -fL -C - --retry 10 --retry-delay 5 --retry-all-errors $curlProg -o $out $url
  if($LASTEXITCODE -ne 0 -or -not (Test-Path $out -PathType Leaf) -or (Get-Item $out).Length -eq 0){
    Log "ERROR: download failed: $url -> $out. Re-run the installer to resume."
    exit 1
  }
}
function UA(){ 'Mozilla/5.0' }
# Size of a remote file in bytes after redirects ('' if the server does not say).
function Remote-Size($url){
  $n = ''
  foreach($l in (curl.exe -sIL -A (UA) $url 2>$null)){ if("$l" -match '^\s*content-length:\s*(\d+)'){ $n = $Matches[1] } }
  if($n -and [int64]$n -gt 0){ $n } else { '' }
}
# Fetch-Sized url out bytes: for a file whose name stays the same when the source
# publishes a new edition (#57). A file of the right size is kept. Otherwise the new
# edition goes to a part file whose name carries its size, so a re-run never resumes
# one edition into another, and it replaces the old file only once it is complete.
# With no size known, this is a plain Fetch.
function Fetch-Sized($url,$out,$bytes){
  if(-not $bytes){ Fetch $url $out; return }
  if((Test-Path $out -PathType Leaf) -and -not (Test-Path "$out.aria2") -and (Get-Item $out).Length -eq [int64]$bytes){ return }
  $part = "$out.$bytes.part"
  Get-ChildItem -Path (Split-Path $out -Parent) -Filter ((Split-Path $out -Leaf) + '.*.part') -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $part } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath ($_.FullName + '.aria2') -Force -ErrorAction SilentlyContinue }
  if(Test-Path $out -PathType Leaf){ Log "  re-download: $(Split-Path $out -Leaf) (size on disk is not the source's $bytes bytes)" }
  Fetch $url $part
  $got = (Get-Item $part).Length
  if($got -ne [int64]$bytes){
    Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath "$part.aria2" -Force -ErrorAction SilentlyContinue
    Log "ERROR: $(Split-Path $out -Leaf): got $got bytes, expected $bytes. Re-run the installer."
    exit 1
  }
  Remove-Item -LiteralPath "$out.aria2" -Force -ErrorAction SilentlyContinue
  Move-Item -LiteralPath $part -Destination $out -Force
}
if($UseAria){ Log 'Downloader: aria2 (fast, multi-connection)' } else { Log "Downloader: curl (tip: install 'aria2' for much faster downloads)" }
if($Lite){ Log "Lite preset: 3B AI, medical/survival references and maps for '$Region' (unless skipped). Size depends on region; use -Region for a small area or -SkipMaps. Re-run without -Lite to add the full library." }

# free-space check (needs roughly 60 GB for everything)
try {
  $drive = (Get-Item $Root).PSDrive
  $freeGB = [math]::Round((Get-PSDrive $drive.Name).Free/1GB,1)
  Log "Destination: $Root   (free space: $freeGB GB)"
  if (-not $Lite -and $freeGB -lt 65) { Log "WARNING: ~65 GB recommended for the full library. You have $freeGB GB free. Consider -SkipWikipedia / -SkipMaps / -SkipModels." }
} catch {}

# ---------------------------------------------------------------- folder tree
$dirs = @(
 'AI-Offline','AI-Offline\engine','AI-Offline\models','AI-Offline\DocReader-GPT4All',
 'Manuals','Manuals\ArmyFieldManuals','Manuals\Repair-iFixit','Manuals\DIY-Appropedia',
 'Manuals\Survival-Water-Food','Manuals\Radio-Communications','Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015',
 'Medical','Medical\WikiMed','Medical\zimgit-medicine','Medical\Manuals-PDF',
 'Wikipedia','OsmAnd','Kiwix-Reader','Kiwix-Reader\app','Phone-Apps','Education'
)
foreach($d in $dirs){ New-Item -ItemType Directory -Force (Join-Path $Root $d) | Out-Null }

# ---------------------------------------------------------------- helpers
function Latest-Zim($dirUrl,$prefix){
  $html = curl.exe -sL -A (UA) $dirUrl
  $names = [regex]::Matches($html, [regex]::Escape($prefix)+'[^"<]*\.zim') | ForEach-Object {$_.Value} | Sort-Object -Unique
  if($names){ return ($names | Select-Object -Last 1) } else { return $null }
}
function Gh-ReleaseWith($repo,$needle){
  $rels = Invoke-RestMethod "https://api.github.com/repos/$repo/releases?per_page=20" -Headers @{'User-Agent'='ps'}
  foreach($r in $rels){ if($r.assets | Where-Object { $_.name -match $needle }){ return $r } }
  return $null
}

# ================================================================ 1. AI engine
# llama.cpp for Windows, macOS and Linux, all from ONE build, so a drive made on any
# computer runs the AI on any other. Folder names match the .bat/.sh launchers below.
Log '=== [1/8] Offline AI engine (llama.cpp) for Windows, macOS and Linux ==='
$LlamaAssets = [ordered]@{ 'win-cpu-x64.zip'='x64'; 'win-cpu-arm64.zip'='arm64'; 'win-vulkan-x64.zip'='vulkan-x64'
  'macos-arm64.tar.gz'='macos-arm64'; 'macos-x64.tar.gz'='macos-x64'
  'ubuntu-x64.tar.gz'='linux-x64'; 'ubuntu-arm64.tar.gz'='linux-arm64'; 'ubuntu-vulkan-x64.tar.gz'='linux-vulkan-x64' }
# Expand-Tgz: unpack a .tar.gz with its symlinks turned into real files. exFAT has no symlinks
# and Windows tar often cannot create them, so unpack to a temp folder, replace each link
# with a copy of its target, then copy the result onto the drive.
function Expand-Tgz($file,$dest){
  $tarExe = if (Get-Command tar.exe -ErrorAction SilentlyContinue) { 'tar.exe' } else { 'tar' }
  $t = Join-Path ([System.IO.Path]::GetTempPath()) ('oel-untar-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force $t, $dest | Out-Null
  try {
    & $tarExe -xzf $file -C $t 2>$null
    $links = @(& $tarExe -tvzf $file | Where-Object { $_ -match '^l' -and $_ -match ' -> ' })
    for ($pass = 0; $pass -lt 5; $pass++) {          # a link can point at another link: repeat
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
  } finally { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
}
try{
  $rels = Invoke-RestMethod 'https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=20' -Headers @{'User-Agent'='ps'}
  $lt = $null
  foreach($r in @($rels)){
    $names = @($r.assets | ForEach-Object { $_.name })
    $ok = $true; foreach($x in $LlamaAssets.Keys){ if($names -notcontains "llama-$($r.tag_name)-bin-$x"){ $ok = $false; break } }
    if($ok){ $lt = $r.tag_name; break }
  }
  if(-not $lt){ Log 'engine: no recent llama.cpp build has all 8 platform files' }
  else {
    Log "engine: llama.cpp $lt"
    $e = Join-Path $Root 'AI-Offline\engine'
    foreach($x in $LlamaAssets.Keys){
      # The build tag is in the file name: a re-run on a newer build must not resume into
      # the old build's archive (curl -C - / aria2 -c would append to it - see #35).
      $out = Join-Path $e "$lt-$x"; $dest = Join-Path $e $LlamaAssets[$x]
      Log "engine: $x"; Fetch "https://github.com/ggml-org/llama.cpp/releases/download/$lt/llama-$lt-bin-$x" $out
      if(Test-Path $dest){ Remove-Item $dest -Recurse -Force }   # fresh unpack: no files left from an older build
      try{ if($x -like '*.zip'){ Expand-Archive $out -DestinationPath $dest -Force } else { Expand-Tgz $out $dest } }
      catch{ Log "ERROR: could not unpack ${x} ($out): $($_.Exception.Message). Delete it and re-run."; exit 1 }
      # A damaged zip can unpack to nothing with no error on PowerShell 5.1 (#35): check the program is there.
      if(-not (Get-ChildItem -LiteralPath $dest -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'llama-cli' -or $_.Name -eq 'llama-cli.exe' } | Select-Object -First 1)){ Log "ERROR: unpacked ${x} ($out), but llama-cli is not in it. Delete it and re-run."; exit 1 }
    }
    # Archives from other builds (and the old names without a tag) are no longer needed.
    Get-ChildItem -LiteralPath $e -File | Where-Object { ($_.Name -like '*.zip' -or $_.Name -like '*.tar.gz') -and -not $_.Name.StartsWith("$lt-") } | Remove-Item -Force
    Set-Content -Path (Join-Path $e 'BUILD.txt') -Value $lt -Encoding ascii
  }
}catch{ Log "engine ERROR: $($_.Exception.Message)" }

# ================================================================ 2. AI models
Log '=== [2/8] AI chat models (GGUF, Q4_K_M) ==='
$models = @(
 @{n='Llama-3.2-3B-Instruct-Q4_K_M.gguf';      u='https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf'; big=$false}
 @{n='Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf'; u='https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf'; big=$true}
 @{n='Qwen2.5-7B-Instruct-Q4_K_M.gguf';        u='https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf'; big=$true}
)
foreach($m in $models){
  if($SkipModels -and $m.big){ Log "model (skipped): $($m.n)"; continue }
  Log "model: $($m.n)"; Fetch $m.u (Join-Path $Root "AI-Offline\models\$($m.n)")
}
# Translator (opt-in): one small multilingual model run by the same engine, so no new runtime.
$TrModel = 'Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf'
if($Translate){
  Log "model (translator): $TrModel"
  Fetch "https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-2507-GGUF/resolve/main/$TrModel" (Join-Path $Root "AI-Offline\models\$TrModel")
} else { Log '=== Translator not selected - add -Translate to include (~2.5 GB) ===' }

# ================================================================ 3. GPT4All
Log '=== [3/8] GPT4All (offline document Q&A) ==='
if(-not $Lite){
try{
  $rel = Gh-ReleaseWith 'nomic-ai/gpt4all' 'installer-win64-v'
  $a = $rel.assets | Where-Object { $_.name -match 'installer-win64-v.*\.exe$' -and $_.name -notmatch 'arm' } | Select-Object -First 1
  if($a){ Log "gpt4all: $($a.name)"; Fetch $a.browser_download_url (Join-Path $Root "AI-Offline\DocReader-GPT4All\$($a.name)") }
}catch{ Log "gpt4all ERROR: $($_.Exception.Message)" }
} else {
  Log 'gpt4all: skipped (lite preset)'
  @(
    'GPT4All (offline document Q&A) is NOT included in a -Lite install.',
    '',
    'This lite drive has only the plain AI chat (the 3B model), which does not cite',
    'sources. Treat its answers as leads and verify anything safety-critical against the',
    'manuals on this drive.',
    '',
    'To add GPT4All and its source-citing LocalDocs workflow:',
    '  - re-run the installer into this same drive WITHOUT -Lite, or',
    '  - install GPT4All from gpt4all.io while you still have internet.',
    'See HOW-TO-ASK-YOUR-DOCS.html in this folder.'
  ) | Set-Content -LiteralPath (Join-Path $Root 'AI-Offline\DocReader-GPT4All\GPT4All-NOT-INCLUDED-IN-LITE.txt') -Encoding UTF8
}

# ================================================================ 4. Kiwix reader
Log '=== [4/8] Kiwix reader (portable) ==='
try{
  $kdir = 'https://download.kiwix.org/release/kiwix-desktop/'
  $html = curl.exe -sL -A (UA) $kdir
  $zip = [regex]::Matches($html,'kiwix-desktop_windows_x64_[0-9][^"<]*\.zip') | ForEach-Object {$_.Value} | Sort-Object -Unique | Select-Object -Last 1
  if($zip){
    $out = Join-Path $Root "Kiwix-Reader\$zip"
    Log "kiwix: $zip"; Fetch ($kdir+$zip) $out
    try{ Expand-Archive $out -DestinationPath (Join-Path $Root 'Kiwix-Reader\app') -Force }catch{ Log "  extract failed: $($_.Exception.Message)" }
  }
}catch{ Log "kiwix ERROR: $($_.Exception.Message)" }

# ================================================================ 5. ZIM archives
Log '=== [5/8] Offline archives (Kiwix ZIM: repair, DIY, medical, survival) ==='
$zims = @(
 @{dir='https://download.kiwix.org/zim/ifixit/'; pre='ifixit_en_all_';            d='Manuals\Repair-iFixit'}
 @{dir='https://download.kiwix.org/zim/other/';  pre='appropedia_en_all_maxi_';   d='Manuals\DIY-Appropedia'}
 @{dir='https://download.kiwix.org/zim/other/';  pre='zimgit-post-disaster_en_';  d='Manuals\Survival-Water-Food'}
 @{dir='https://download.kiwix.org/zim/other/';  pre='zimgit-water_en_';          d='Manuals\Survival-Water-Food'}
 @{dir='https://download.kiwix.org/zim/other/';  pre='zimgit-food-preparation_en_'; d='Manuals\Survival-Water-Food'}
 @{dir='https://download.kiwix.org/zim/other/';  pre='zimgit-knots_en_';          d='Manuals\Survival-Water-Food'}
 @{dir='https://download.kiwix.org/zim/wikipedia/'; pre='wikipedia_en_medicine_maxi_'; d='Medical\WikiMed'}
 @{dir='https://download.kiwix.org/zim/other/';  pre='zimgit-medicine_en_';       d='Medical\zimgit-medicine'}
)
foreach($z in $zims){
  if($Lite -and $z.d -in @('Manuals\Repair-iFixit','Manuals\DIY-Appropedia')){ continue }
  $name = Latest-Zim $z.dir $z.pre
  if($name){ Log "zim: $name"; Fetch ($z.dir+$name) (Join-Path $Root "$($z.d)\$name") }
  else { Log "zim: NOT FOUND for prefix $($z.pre)" }
}

# ================================================================ 5b. Education (opt-in)
if($Education){
  Log "=== [5b] Education: Khan Academy (Kiwix ZIM, ~168 GB with videos, lang=$EduLang) ==="
  New-Item -ItemType Directory -Force (Join-Path $Root 'Education\KhanAcademy') | Out-Null
  $kaName = Latest-Zim 'https://download.kiwix.org/zim/other/' "khanacademy_$($EduLang)_all_"
  if($kaName){ Log "zim: $kaName"; Fetch ("https://download.kiwix.org/zim/other/$kaName") (Join-Path $Root "Education\KhanAcademy\$kaName") }
  else { Log "Khan Academy: no ZIM found for language '$EduLang' (try -EduLang en|es|fr)" }
} else { Log "=== [5b] Education (Khan Academy) not selected - add -Education to include (~168 GB) ===" }

# ================================================================ 5c. Kolibri app (opt-in)
if($Kolibri){
  Log "=== [5c] Kolibri learning app (pick subjects + low-res in-app) ==="
  $kdir = Join-Path $Root 'Education\Kolibri'; New-Item -ItemType Directory -Force $kdir | Out-Null
  $rel = Gh-ReleaseWith 'learningequality/kolibri' 'windows-setup\.exe'
  if($rel){
    foreach($p in @('windows-setup\.exe$','\.dmg$','_all\.deb$','\.pex$')){
      $a = $rel.assets | Where-Object { $_.name -match $p } | Select-Object -First 1
      if($a){ Log "kolibri: $($a.name)"; Fetch $a.browser_download_url (Join-Path $kdir $a.name) }
    }
    $apk = $rel.assets | Where-Object { $_.name -match 'universal\.apk$' } | Select-Object -First 1
    if($apk){ New-Item -ItemType Directory -Force (Join-Path $Root 'Phone-Apps') | Out-Null; Log "kolibri apk: $($apk.name)"; Fetch $apk.browser_download_url (Join-Path $Root "Phone-Apps\$($apk.name)") }
  } else { Log 'Kolibri: no release found' }
} else { Log "=== [5c] Kolibri not selected - add -Kolibri to include ===" }

# ================================================================ 5d. Extra archives (opt-in)
# Wikivoyage (travel guide, ~1.1 GB) + Wikibooks (open textbooks, ~4.7 GB), both CC BY-SA.
# WikiHow is not included: download.kiwix.org no longer publishes it.
if($ExtraZims){
  Log '=== [5d] Extra archives: Wikivoyage + Wikibooks (Kiwix ZIM, ~5.8 GB) ==='
  $extra = @(
   @{dir='https://download.kiwix.org/zim/wikivoyage/'; pre='wikivoyage_en_all_maxi_'; d='Extra-Archives\Wikivoyage'}
   @{dir='https://download.kiwix.org/zim/wikibooks/';  pre='wikibooks_en_all_maxi_';  d='Extra-Archives\Wikibooks'}
  )
  foreach($z in $extra){
    New-Item -ItemType Directory -Force (Join-Path $Root $z.d) | Out-Null
    $name = Latest-Zim $z.dir $z.pre
    if($name){ Log "zim: $name"; Fetch ($z.dir+$name) (Join-Path $Root "$($z.d)\$name") }
    else { Log "zim: NOT FOUND for prefix $($z.pre)" }
  }
} else { Log "=== [5d] Extra archives (Wikivoyage + Wikibooks) not selected - add -ExtraZims to include (~5.8 GB) ===" }

# ================================================================ 5e. MedlinePlus (opt-in)
# Plain-language health topic summaries (English + Spanish) from the US National Library of
# Medicine's daily XML file: public domain. Only the summaries: the MedlinePlus encyclopedia
# (A.D.A.M.) and drug pages (ASHP) are copyrighted, so the Kiwix MedlinePlus ZIM is not used.
# The XML goes inside one offline page (medlineplus\MedlinePlus.html) that lists and searches it.
if($MedlinePlus){
  Log '=== [5e] MedlinePlus health topics (public domain, ~30 MB) ==='
  $md = Join-Path $Root 'Medical\MedlinePlus'; New-Item -ItemType Directory -Force $md | Out-Null
  $mx = [regex]::Matches((curl.exe -sL -A (UA) 'https://medlineplus.gov/xml.html' | Out-String), 'mplus_topics_\d{4}-\d{2}-\d{2}\.xml') | ForEach-Object {$_.Value} | Sort-Object -Unique | Select-Object -Last 1
  if($mx){
    $xf = Join-Path $md $mx
    Log "medlineplus: $mx"; Fetch "https://medlineplus.gov/xml/$mx" $xf
    $xt = [System.IO.File]::ReadAllText($xf, [System.Text.Encoding]::UTF8)
    # '</script' would end the data block early; real topic XML never has it (all HTML is escaped).
    if(-not $xt.StartsWith('<?xml', [StringComparison]::Ordinal) -or -not $xt.Contains('<health-topics') -or $xt -match '(?i)</script'){
      Remove-Item -LiteralPath $xf -Force; Log "ERROR: $mx is not MedlinePlus topic XML (removed). Re-run the installer."; exit 1 }
    $sd = if($PSScriptRoot){$PSScriptRoot}else{(Get-Location).Path}
    $lp = Join-Path $sd 'medlineplus\MedlinePlus.html'; $tpl = Join-Path $md '_MedlinePlus.html'
    if(Test-Path $lp){ Copy-Item $lp $tpl -Force }
    else { curl.exe -fLsS "$RepoRaw/medlineplus/MedlinePlus.html" -A (UA) -o $tpl
      if($LASTEXITCODE -ne 0){ Log 'ERROR: download failed: medlineplus/MedlinePlus.html'; exit 1 } }
    $page = [System.IO.File]::ReadAllText($tpl, [System.Text.Encoding]::UTF8)
    $mark = '<script type="text/xml" id="data"></script>'
    if(-not $page.Contains($mark)){ Log 'ERROR: medlineplus/MedlinePlus.html has no data marker. Re-run the installer.'; exit 1 }
    if(-not $xt.EndsWith("`n")){ $xt += "`n" }  # match the Bash awk splice, which always ends the data with a newline
    $out = Join-Path $md 'MedlinePlus-Health-Topics.html'
    [System.IO.File]::WriteAllText($out, $page.Replace($mark, '<script type="text/xml" id="data">' + $xt + '</script>'), [System.Text.UTF8Encoding]::new($false))
    # The page holds all the data: drop the XML (and any older day's copy) and the template.
    Get-ChildItem -LiteralPath $md -File | Where-Object { $_.Name -like 'mplus_topics_*' -or $_.Name -eq '_MedlinePlus.html' } | Remove-Item -Force
    Log ("medlineplus: Medical\MedlinePlus\MedlinePlus-Health-Topics.html ({0:N0} MB)" -f ((Get-Item $out).Length/1MB))
  } else { Log 'medlineplus: NOT FOUND (no topic file listed on medlineplus.gov/xml.html)' }
} else { Log '=== [5e] MedlinePlus health topics not selected - add -MedlinePlus to include (~30 MB) ===' }

# ================================================================ 6. PDFs (Internet Archive)
Log '=== [6/8] Public-domain manuals (PDF) ==='
$pdfs = @(
 @{id='fm-21-76-us-army-survival-manual';                    n='FM 21-76 Army Survival Manual.pdf';               d='Manuals\ArmyFieldManuals'}
 @{id='fm-3-05.70-survival-2002';                            n='FM 3-05.70 Survival (2002).pdf';                  d='Manuals\ArmyFieldManuals'}
 @{id='105-page-survival-field-manual';                      n='105-Page Survival Field Manual.pdf';              d='Manuals\ArmyFieldManuals'}
 @{id='UsArmyFirstAidManualFm4-25.11';                       n='FM 4-25.11 First Aid.pdf';                        d='Manuals\ArmyFieldManuals'}
 @{id='Survival-FirstAidForSoldiers-AFieldManual';           n='Survival and First Aid for Soldiers.pdf';         d='Manuals\ArmyFieldManuals'}
 @{id='use-and-care-of-hand-tools-and-measuring-tools-1983'; n='TM 9-243 Use and Care of Hand Tools.pdf';         d='Manuals\ArmyFieldManuals'}
 @{id='fm-5-426-carpentry-1995';                             n='FM 5-426 Carpentry.pdf';                          d='Manuals\ArmyFieldManuals'}
 @{id='tm-9-8000-principles-of-automotive-vehicles-1985';    n='TM 9-8000 Principles of Automotive Vehicles.pdf'; d='Manuals\ArmyFieldManuals'}
 @{id='u-s-army-guide-to-rigging';                           n='FM 5-125 Army Guide to Rigging.pdf';              d='Manuals\ArmyFieldManuals'}
 @{id='fm-90-3-desert-operations-1993';                      n='FM 90-3 Desert Operations.pdf';                   d='Manuals\ArmyFieldManuals'}
 @{id='tm-10-412-armed-forces-recipe-service-2003';          n='TM 10-412 Armed Forces Recipe Service.pdf';       d='Manuals\ArmyFieldManuals'}
 @{id='where-there-is-no-doctor';                            n='Where There Is No Doctor.pdf';                    d='Medical\Manuals-PDF'}
 @{id='where-there-is-no-dentist-web-full-book';             n='Where There Is No Dentist.pdf';                   d='Medical\Manuals-PDF'}
 # Advanced care when help is delayed: USUHS + Henry M. Jackson Foundation, 2025, CC BY-NC-SA 4.0 (not public domain)
 @{u='https://www.usuhs.edu/sites/default/files/2025-09/Layperson%27s_Guide_to_Prolonged_Casualty_Care_090825_ACC.pdf'; n='A Practical Guide to Prolonged Casualty Care (USUHS-HJF 2025).pdf'; d='Medical\Manuals-PDF'}
 # WHO childbirth references (CC BY-NC-SA 3.0 IGO); citations, audience and update cautions in Medical/READ-ME-FIRST.
 @{u='https://iris.who.int/server/api/core/bitstreams/3bda1306-da5d-487d-b2ad-aff995112a7a/content'; n='WHO Managing Complications in Pregnancy and Childbirth 2017.pdf'; d='Medical\Manuals-PDF'}
 @{u='https://iris.who.int/server/api/core/bitstreams/12fdb499-733d-4614-aafc-88dcbbb3c829/content'; n='WHO Recommendations on Maternal Health 2025.pdf'; d='Medical\Manuals-PDF'}
 # USDA Complete Guide to Home Canning (AIB 539, revised 2015; US-government work): 8 official PDFs from the USDA-funded NCHFP
 @{u='https://nchfp.uga.edu/papers/guide/INTRO_HomeCanrev0715.pdf'; n='0 Introduction.pdf'; d='Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015'}
 @{u='https://nchfp.uga.edu/papers/guide/GUIDE01_HomeCan_rev0715.pdf'; n='1 Principles of Home Canning.pdf'; d='Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015'}
 @{u='https://nchfp.uga.edu/papers/guide/GUIDE02_HomeCan_rev0715.pdf'; n='2 Fruit and Fruit Products.pdf'; d='Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015'}
 @{u='https://nchfp.uga.edu/papers/guide/GUIDE03_HomeCan_rev0715.pdf'; n='3 Tomatoes and Tomato Products.pdf'; d='Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015'}
 @{u='https://nchfp.uga.edu/papers/guide/GUIDE04_HomeCan_rev0715.pdf'; n='4 Vegetables and Vegetable Products.pdf'; d='Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015'}
 @{u='https://nchfp.uga.edu/papers/guide/GUIDE05_HomeCan_rev0715.pdf'; n='5 Poultry, Red Meats, and Seafoods.pdf'; d='Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015'}
 @{u='https://nchfp.uga.edu/papers/guide/GUIDE06_HomeCan_rev0715.pdf'; n='6 Fermented Foods and Pickled Vegetables.pdf'; d='Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015'}
 @{u='https://nchfp.uga.edu/papers/guide/GUIDE07_HomeCan_rev0715.pdf'; n='7 Jams and Jellies.pdf'; d='Manuals\Food-Preservation\USDA-Complete-Guide-to-Home-Canning-2015'}
)
foreach($p in $pdfs){
  try{
    if($p.u){ $url = $p.u } else {   # direct link, or an archive.org item
      $meta = curl.exe -sL "https://archive.org/metadata/$($p.id)" -A (UA) | ConvertFrom-Json
      $f = $meta.files | Where-Object {$_.name -match '\.pdf$' -and $_.name -notmatch '_text\.pdf$'} | Sort-Object {[double]$_.size} -Descending | Select-Object -First 1
      $url = if($f){ "https://archive.org/download/$($p.id)/$([uri]::EscapeDataString($f.name))" } else { $null }
    }
    if($url){
      $out = Join-Path $Root "$($p.d)\$($p.n)"
      Log "pdf: $($p.n)"
      Fetch $url $out
      if(Test-Path $out){
        $fs = New-Object IO.FileStream($out,'Open'); $b = New-Object byte[] 4; [void]$fs.Read($b,0,4); $fs.Close()
        if(-not ([System.Text.Encoding]::ASCII.GetString($b) -eq '%PDF')){ Log "  ERROR: $($p.n) not a valid PDF (removed)"; Remove-Item $out -Force; exit 1 }
      } else { Log "  WARN: $($p.n) failed to download" }
    } else { Log "pdf: NO PDF for $($p.id)" }
  }catch{ Log "pdf ERROR $($p.n): $($_.Exception.Message)" }
}

# ================================================================ 7. Wikipedia + Maps
if(-not $SkipWikipedia){
  Log '=== [7/8] Wikipedia (full, no images - Kiwix ZIM, ~49 GB) ==='
  $wk = Latest-Zim 'https://download.kiwix.org/zim/wikipedia/' 'wikipedia_en_all_nopic_'
  if($wk){ Log "zim: $wk"; Fetch ("https://download.kiwix.org/zim/wikipedia/$wk") (Join-Path $Root "Wikipedia\$wk") }
  else { Log 'Wikipedia: ZIM not found' }
} else { Log '=== [7/8] Wikipedia SKIPPED ===' }

if(-not $SkipMaps){
  Log "=== [8/8] Offline maps (OsmAnd) - region: $Region ==="
  try{
    $idxFile = Join-Path $env:TEMP 'osmand_idx.xml'
    curl.exe -sL 'https://download.osmand.net/get_indexes' -o $idxFile
    [xml]$idx = Get-Content $idxFile
    $allmaps = $idx.osmand_regions.region | Where-Object { $_.type -eq 'map' }
    # resolve the -Region tokens (comma/space separated) to a file set
    $tokens = ($Region -split '[,; ]') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { Resolve-RegionToken $_ }
    $sel = @()
    foreach($t in $tokens){
      if($t -ieq 'world'){ $sel = $allmaps; break }
      elseif($Continents -contains $t.ToLower()){ $sel += $allmaps | Where-Object { $_.name -match ('_' + [regex]::Escape($t.ToLower()) + '_') } }
      else { $sel += $allmaps | Where-Object { $_.name -match ('^' + [regex]::Escape($t) + '_') } }
    }
    $sel = $sel | Sort-Object name -Unique
    if(-not $sel){
      Log "osmand: no maps matched region '$Region'. Run with -ListRegions to see valid names. Skipping maps."
    } else {
      $mb = ($sel | Measure-Object -Property size -Sum).Sum
      Log ("osmand: {0} map files for '{1}' (~{2:N1} GB download)" -f $sel.Count, $Region, ($mb/1024))
      if($mb -gt 40000){ Log ("WARNING: that's ~{0:N0} GB of maps - make sure you have room (and time)." -f ($mb/1024)) }
      # OsmAnd republishes maps under the same name: the index's containerSize (bytes)
      # tells a current copy from an older edition (#57).
      foreach($r in $sel){
        $out = Join-Path $Root "OsmAnd\$($r.name)"
        Fetch-Sized "https://download.osmand.net/download.php?standard=yes&file=$($r.name)" $out $r.containerSize
      }
    }
  }catch{ Log "osmand ERROR: $($_.Exception.Message)" }
} else { Log '=== [8/8] Maps SKIPPED ===' }

# ---------------- desktop map viewer (use the maps on a PC, no phone needed) -----------
if(-not $SkipMaps){
  Log '=== [8b] Desktop map viewer (OsmAndMapCreator + portable Java) ==='
  $mvd = Join-Path $Root 'OsmAnd\MapViewer-Desktop'
  New-Item -ItemType Directory -Force $mvd,(Join-Path $mvd 'app') | Out-Null
  try{
    $mc = Join-Path $mvd 'OsmAndMapCreator.zip'
    Log 'mapviewer: OsmAndMapCreator'
    # "latest" URLs keep their file name across new editions: fetch by remote size (#57)
    $mcu = 'https://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip'
    Fetch-Sized $mcu $mc (Remote-Size $mcu)
    # unpack to a new folder; replace the working viewer only if the unpack worked.
    # (PowerShell 5.1 Expand-Archive can "succeed" on a damaged zip with 0 files, so check the file.)
    $appNew = Join-Path $mvd 'app.new'
    if(Test-Path $appNew){ Remove-Item $appNew -Recurse -Force }
    try{ Expand-Archive $mc -DestinationPath $appNew -Force }catch{ Log "  extract failed: $($_.Exception.Message)" }
    # if the zip nested everything in a single subfolder, pull it up to \app.new
    if((Test-Path $appNew) -and -not (Test-Path (Join-Path $appNew 'OsmAndMapCreator.bat'))){
      $inner = Get-ChildItem $appNew -Directory | Select-Object -First 1
      if($inner -and (Test-Path (Join-Path $inner.FullName 'OsmAndMapCreator.bat'))){
        Get-ChildItem $inner.FullName -Force | Move-Item -Destination $appNew -Force
      }
    }
    if(Test-Path (Join-Path $appNew 'OsmAndMapCreator.bat')){
      $app = Join-Path $mvd 'app'; if(Test-Path $app){ Remove-Item $app -Recurse -Force }
      Move-Item $appNew $app
    } else {
      Remove-Item $appNew -Recurse -Force -ErrorAction SilentlyContinue
      Log '  mapviewer ERROR: could not unpack OsmAndMapCreator.zip (old viewer kept). Delete it and re-run.'
    }
    $jz = Join-Path $mvd 'jre.zip'
    Log 'mapviewer: portable Java runtime'
    $jru = 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse'
    Fetch-Sized $jru $jz (Remote-Size $jru)
    $tmp = Join-Path $mvd '_jre_tmp'
    if(Test-Path $tmp){ Remove-Item $tmp -Recurse -Force }
    try{ Expand-Archive $jz -DestinationPath $tmp -Force }catch{ Log "  extract failed: $($_.Exception.Message)" }
    $jreSrc = Get-ChildItem $tmp -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if($jreSrc -and (Test-Path (Join-Path $jreSrc.FullName 'bin\java.exe'))){
      $jreDst = Join-Path $mvd 'jre'
      if(Test-Path $jreDst){ Remove-Item $jreDst -Recurse -Force }
      Move-Item $jreSrc.FullName $jreDst
    } else { Log '  mapviewer ERROR: could not unpack jre.zip (old Java kept). Delete it and re-run.' }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }catch{ Log "mapviewer ERROR: $($_.Exception.Message)" }

  # helper: unzip the downloaded .obf.zip map files into an \obf folder the viewer can read
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
echo.
echo If the map area stays BLANK (a known OsmAndMapCreator issue on some Windows PCs):
echo   - best: use the browser maps - run  Maps-Browser\OPEN-MAPS.bat  (if you built the
echo     drive with -BrowserMaps; US street maps, renders reliably on Windows), or
echo   - use the maps on an Android phone/tablet (see OsmAnd\HOW-TO-VIEW-MAPS.html).
cd /d "%~dp0app"
call OsmAndMapCreator.bat
pause
"@
  Set-Content -Path (Join-Path $mvd 'VIEW-MAPS-ON-PC.bat') -Value $mvbat -Encoding ascii
}

# ================================================================ 8c. Browser maps (opt-in)
# Street maps in any web browser on Windows, macOS and Linux - no app, no Java. Protomaps
# state maps made by Project NOMAD (MIT; map data (c) OpenStreetMap contributors, ODbL),
# NOMAD's style/fonts/symbols, the MapLibre GL JS viewer (BSD-3) and Caddy (Apache-2.0) as a
# local web server. NOMAD has US states only; any region also gets a low-detail world map.
if((-not $SkipMaps) -and $BrowserMaps){
  Log '=== [8c] Browser maps (Project NOMAD / Protomaps + MapLibre + Caddy) ==='
  $mb = Join-Path $Root 'Maps-Browser'
  foreach($d in 'pmtiles','viewer\lib','server'){ New-Item -ItemType Directory -Force (Join-Path $mb $d) | Out-Null }
  $nm = 'https://github.com/Crosstalk-Solutions/project-nomad-maps/raw/refs/heads/master'
  try{
    # which states: US / world / northamerica = all; Us_<state>[_<area>] = that state
    $want = @(($Region -split '[,; ]') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object {
      $t = (Resolve-RegionToken $_).ToLower()
      if(@('us','world','northamerica') -contains $t){ 'ALL' } elseif($t.StartsWith('us_')){ $t.Substring(3).Replace('-','_') }
    })
    $names = @((Invoke-RestMethod 'https://api.github.com/repos/Crosstalk-Solutions/project-nomad-maps/contents/pmtiles' -Headers @{'User-Agent'='ps'}) |
      ForEach-Object { $_.name } | Where-Object { $_ -cmatch '^[a-z_-]+_\d{4}-\d{2}\.pmtiles$' } | Sort-Object)
    # newest file per map (names end _YYYY-MM.pmtiles); the world map first so states draw over it
    $list = @()
    foreach($g in ($names | Group-Object { $_ -replace '_\d{4}-\d{2}\.pmtiles$','' } | Sort-Object Name)){
      $r = $g.Name
      $keep = $r.StartsWith('global')
      foreach($w in $want){ if($w -eq 'ALL' -or $w -eq $r -or $w.StartsWith($r + '_')){ $keep = $true } }
      if($keep){ $list += ($g.Group | Sort-Object | Select-Object -Last 1) }
    }
    $list = @($list | Where-Object { $_.StartsWith('global') }) + @($list | Where-Object { -not $_.StartsWith('global') })
    $ns = @($list | Where-Object { -not $_.StartsWith('global') }).Count
    if($ns -eq 0){ Log "browser maps: no US state in region '$Region' (these maps cover the US) - adding the world map only" }
    Log "browser maps: $($list.Count) map files ($ns US states)"
    $ok = @()
    foreach($fn in $list){
      $out = Join-Path $mb "pmtiles\$fn"
      Log "map: $fn"; Fetch "$nm/pmtiles/$fn" $out
      # no published fingerprints: check the PMTiles header (the file starts with "PMTiles")
      $hdr = ''; if(Test-Path $out){ $fs = [System.IO.File]::OpenRead($out); $buf = New-Object byte[] 7; [void]$fs.Read($buf,0,7); $fs.Close(); $hdr = [System.Text.Encoding]::ASCII.GetString($buf) }
      if($hdr -eq 'PMTiles'){ $ok += $fn } else { Log "  WARN: $fn is not a PMTiles file (removed) - run again"; Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
    }
    if($ok.Count){ [System.IO.File]::WriteAllText((Join-Path $mb 'regions.json'), ('[' + (($ok | ForEach-Object { '"' + $_ + '"' }) -join ',') + "]`n"), [System.Text.UTF8Encoding]::new($false)) }
    # map style, fonts and symbols (one archive, no symlinks inside)
    $ba = Join-Path $mb 'base-assets.tar.gz'; Fetch-Sized "$nm/base-assets.tar.gz" $ba (Remote-Size "$nm/base-assets.tar.gz")   # same name on every update (#57)
    $new = Join-Path $mb 'assets-new'; if(Test-Path $new){ Remove-Item $new -Recurse -Force }; New-Item -ItemType Directory -Force $new | Out-Null
    $tarExe = if(Get-Command tar.exe -ErrorAction SilentlyContinue){ 'tar.exe' } else { 'tar' }
    & $tarExe -xzf $ba -C $new 2>$null
    if(Test-Path (Join-Path $new 'tozip\nomad-base-styles.json')){
      $old = Join-Path $mb 'assets'; if(Test-Path $old){ Remove-Item $old -Recurse -Force }
      Move-Item (Join-Path $new 'tozip') $old
    } else { Log '  WARN: could not unpack the map style and fonts (base-assets.tar.gz)' }
    Remove-Item $new -Recurse -Force -ErrorAction SilentlyContinue
    # map viewer libraries (pinned versions)
    foreach($u in 'maplibre-gl@4.7.1/dist/maplibre-gl.js','maplibre-gl@4.7.1/dist/maplibre-gl.css','pmtiles@4.4.0/dist/pmtiles.js'){
      $f = Join-Path $mb ('viewer\lib\' + (Split-Path $u -Leaf)); Fetch "https://unpkg.com/$u" $f
      if(-not ((Test-Path $f) -and (Select-String -Path $f -Pattern 'maplibregl|pmtiles' -Quiet))){ Log "  WARN: $(Split-Path $u -Leaf) did not download (removed)"; Remove-Item $f -Force -ErrorAction SilentlyContinue }
    }
    # Caddy web server for every platform (one release); folder = <os>-<arch>
    $crel = Invoke-RestMethod 'https://api.github.com/repos/caddyserver/caddy/releases/latest' -Headers @{'User-Agent'='ps'}
    foreach($ck in 'windows_amd64.zip','windows_arm64.zip','mac_arm64.tar.gz','mac_amd64.tar.gz','linux_amd64.tar.gz','linux_arm64.tar.gz'){
      $a = $crel.assets | Where-Object { $_.name -like "*_$ck" } | Select-Object -First 1
      if(-not $a){ Log "  WARN: caddy $ck not in the latest Caddy release"; continue }
      $dir = ($ck -replace '\.(zip|tar\.gz)$','') -replace '_','-'
      $out = Join-Path $mb "server\$($a.name)"; $dest = Join-Path $mb "server\$dir"
      Log "caddy: $($a.name)"; Fetch $a.browser_download_url $out
      if(Test-Path $dest){ Remove-Item $dest -Recurse -Force }; New-Item -ItemType Directory -Force $dest | Out-Null   # keeps Caddy's LICENSE (Apache-2.0)
      try{ if($ck -like '*.zip'){ Expand-Archive $out -DestinationPath $dest -Force } else { & $tarExe -xzf $out -C $dest } }catch{ Log "  WARN: could not unpack ${ck}: $($_.Exception.Message)" }
    }
    # viewer page + OPEN-MAPS launchers: from the repo (local clone, else GitHub). The .bat gets
    # Windows line ends and the .sh Unix line ends, whatever the source had.
    $sd = if($PSScriptRoot){$PSScriptRoot}else{(Get-Location).Path}
    foreach($f in 'index.html','OPEN-MAPS.sh','OPEN-MAPS.bat'){
      $lp = Join-Path $sd "maps-viewer\$f"; $tmp = Join-Path $mb "_$f"
      if(Test-Path $lp){ Copy-Item $lp $tmp -Force } else { curl.exe -sL "$RepoRaw/maps-viewer/$f" -A (UA) -o $tmp }
    }
    Move-Item (Join-Path $mb '_index.html') (Join-Path $mb 'viewer\index.html') -Force
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $sh = [System.IO.File]::ReadAllText((Join-Path $mb '_OPEN-MAPS.sh')).Replace("`r`n","`n")
    [System.IO.File]::WriteAllText((Join-Path $mb 'OPEN-MAPS.sh'), $sh, $utf8)
    $bat = [System.IO.File]::ReadAllText((Join-Path $mb '_OPEN-MAPS.bat')).Replace("`r`n","`n").Replace("`n","`r`n")
    [System.IO.File]::WriteAllText((Join-Path $mb 'OPEN-MAPS.bat'), $bat, $utf8)
    Remove-Item (Join-Path $mb '_OPEN-MAPS.sh'),(Join-Path $mb '_OPEN-MAPS.bat') -Force
    Log 'browser maps: run Maps-Browser\OPEN-MAPS (.bat on Windows, .sh on macOS/Linux)'
  }catch{ Log "browser maps ERROR: $($_.Exception.Message)" }
} else {
  Log "=== [8c] Browser maps not selected - add -BrowserMaps to include (~16.5 GB for the US) ==="
  if(-not $SkipMaps){ Log "  Tip (Windows): browser maps is the reliable desktop viewer - the bundled OsmAndMapCreator can render a blank map on some Windows PCs (#15). Re-run with -BrowserMaps to add US street maps that open in any browser." }
}

# ================================================================ phone apps
Log '=== Phone apps (port the library to a phone) ==='
$pa = Join-Path $Root 'Phone-Apps'
New-Item -ItemType Directory -Force $pa | Out-Null
# Kiwix for Android — reads ALL the .zim archives (Wikipedia, medical, repair, survival)
try{
  $kr = Invoke-RestMethod 'https://api.github.com/repos/kiwix/kiwix-android/releases/latest' -Headers @{'User-Agent'='ps'}
  $ka = $kr.assets | Where-Object { $_.name -match 'universal-standalone\.apk$' } | Select-Object -First 1
  if(-not $ka){ $ka = $kr.assets | Where-Object { $_.name -match '\.apk$' } | Select-Object -First 1 }
  if($ka){ Log "phone app: Kiwix ($($ka.name))"; Fetch $ka.browser_download_url (Join-Path $pa $ka.name) }
}catch{ Log "kiwix apk ERROR: $($_.Exception.Message)" }
# OsmAnd for Android — offline maps (only if maps were downloaded)
if(-not $SkipMaps){
  try{
    $api = Invoke-RestMethod 'https://f-droid.org/api/v1/packages/net.osmand.plus' -Headers @{'User-Agent'='ps'}
    $vc = $api.suggestedVersionCode
    Log "phone app: OsmAnd~ (net.osmand.plus_$vc)"
    Fetch "https://f-droid.org/repo/net.osmand.plus_$vc.apk" (Join-Path $pa "OsmAnd-$vc.apk")
  }catch{ Log "osmand apk ERROR: $($_.Exception.Message)" }
}

# ================================================================ launchers
Log '=== Writing launchers (.bat + .sh) ==='
function WriteBat($path,$text){ Set-Content -Path $path -Value $text -Encoding ascii }
$ao = Join-Path $Root 'AI-Offline'
WriteBat (Join-Path $ao 'CHAT-3B-light.bat') @"
@echo off
title Offline AI - Llama 3.2 3B (light)
cd /d "%~dp0"
echo The AI is a helper for finding and summarizing info - for anything safety-critical, follow the bundled manuals.
"%~dp0engine\x64\llama-cli.exe" -m "%~dp0models\Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096
pause
"@
if(-not $Lite){
WriteBat (Join-Path $ao 'CHAT-8B-smart.bat') @"
@echo off
title Offline AI - Llama 3.1 8B (smart)
cd /d "%~dp0"
echo The AI is a helper for finding and summarizing info - for anything safety-critical, follow the bundled manuals.
"%~dp0engine\x64\llama-cli.exe" -m "%~dp0models\Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" -c 4096
pause
"@
WriteBat (Join-Path $ao 'CHAT-GPU-Qwen7B.bat') @"
@echo off
title Offline AI - Qwen2.5 7B (GPU)
cd /d "%~dp0"
echo If this errors with out-of-memory, your GPU is too small - change -ngl 99 to a lower
echo number (e.g. -ngl 20) or use a CPU launcher instead.
echo The AI is a helper for finding and summarizing info - for anything safety-critical, follow the bundled manuals.
"%~dp0engine\vulkan-x64\llama-cli.exe" -m "%~dp0models\Qwen2.5-7B-Instruct-Q4_K_M.gguf" -c 4096 -ngl 99
pause
"@
}
WriteBat (Join-Path $ao 'WEB-UI.bat') @"
@echo off
title Offline AI - Web UI
cd /d "%~dp0"
echo When it says "server listening", open a browser to http://127.0.0.1:8080
echo The AI is a helper for finding and summarizing info - for anything safety-critical, follow the bundled manuals.
"%~dp0engine\x64\llama-server.exe" -m "%~dp0models\Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096 --host 127.0.0.1 --port 8080
pause
"@

# .sh launchers for macOS / Linux: same text as get-offline-library.sh writes (LF line ends,
# UTF-8 without BOM). Each one picks the engine folder for the computer it runs on.
$ShTemplate = @'
#!/usr/bin/env bash
# Offline AI (macOS / Linux). Uses the engine folder for this computer.
DIR="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) P=macos-arm64 ;;
  Darwin-*) P=macos-x64 ;;
  Linux-aarch64|Linux-arm64) P=linux-arm64 ;;
  *) P=linux-x64 ;;
esac
[ "__GPU__" = 1 ] && [ "$P" = linux-x64 ] && P=linux-vulkan-x64
BIN="$(find "$DIR/engine/$P" -name __TOOL__ -type f 2>/dev/null | head -n1)"
[ -z "$BIN" ] && { echo "AI engine for this computer not found: $DIR/engine/$P"; exit 1; }
chmod +x "$BIN" 2>/dev/null
LIBDIR="$(dirname "$BIN")"
export LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="$LIBDIR:${DYLD_LIBRARY_PATH:-}"
echo "__NOTE__"
echo "The AI is a helper for finding and summarizing info - for anything safety-critical, follow the bundled manuals."
exec "$BIN" -m "$DIR/models/__MODEL__" __ARGS__
'@
function WriteSh($name,$tool,$model,$gpu,$argv,$note){
  $t = $ShTemplate.Replace("`r`n","`n").Replace('__TOOL__',$tool).Replace('__MODEL__',$model).Replace('__GPU__',$gpu).Replace('__ARGS__',$argv).Replace('__NOTE__',$note)
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  [System.IO.File]::WriteAllText((Join-Path $ao $name), $t, [System.Text.UTF8Encoding]::new($false))
}
WriteSh 'chat-3B-light.sh'   'llama-cli'    'Llama-3.2-3B-Instruct-Q4_K_M.gguf'      '0' '-c 4096' 'Offline AI - Llama 3.2 3B (light). Ctrl+C to quit.'
if(-not $Lite){
WriteSh 'chat-8B-smart.sh'   'llama-cli'    'Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf' '0' '-c 4096' 'Offline AI - Llama 3.1 8B (smart). Ctrl+C to quit.'
WriteSh 'chat-GPU-Qwen7B.sh' 'llama-cli'    'Qwen2.5-7B-Instruct-Q4_K_M.gguf'        '1' '-c 4096 -ngl 99' 'Offline AI - Qwen2.5 7B on the GPU (Metal on a Mac, Vulkan on Linux).'
}
WriteSh 'web-ui.sh'          'llama-server' 'Llama-3.2-3B-Instruct-Q4_K_M.gguf'      '0' '-c 4096 --host 127.0.0.1 --port 8080' "Open http://127.0.0.1:8080 when it says 'server is listening'."
if($Translate){
# Same text as get-offline-library.sh. No batch special characters in the prompt or notes.
$TrArgs = '-c 4096 --temp 0.2 -sys "You are an interpreter between two people. Their first message names two languages: reply only with Ready. After that, for every message: if it is written in the first language, translate it into the second language; if it is written in the second language, translate it into the first language. Never repeat a message in the language it was written in. Write only the translation, with no notes. Keep names, numbers, doses and times exactly as written."'
WriteBat (Join-Path $ao 'TRANSLATE.bat') @"
@echo off
title Offline translator - Qwen3 4B
cd /d "%~dp0"
echo Offline translator. First type the two languages, for example: English and Spanish. Then type what to translate.
echo Check anything about medicine, doses or safety by translating it back. Use short, simple sentences.
echo The AI is a helper for finding and summarizing info - for anything safety-critical, follow the bundled manuals.
"%~dp0engine\x64\llama-cli.exe" -m "%~dp0models\$TrModel" $TrArgs
pause
"@
WriteSh 'translate.sh' 'llama-cli' $TrModel '0' $TrArgs 'Offline translator. First type the two languages, for example: English and Spanish. Check anything about medicine, doses or safety by translating it back. Ctrl+C to quit.'
}

# ================================================================ documentation
Log '=== Documentation (Markdown + HTML) ==='
# doc source: local .\docs if present (repo clone), else download pre-rendered files from GitHub raw
$scriptDir = if($PSScriptRoot){$PSScriptRoot}else{(Get-Location).Path}
$localDocs = Join-Path $scriptDir 'docs'
# Byte-for-byte copy so UTF-8 (em dashes, emoji) is never re-encoded/garbled.
function PlaceDoc($srcName,$destPath,$title){
  $base = $srcName -replace '\.md$',''
  foreach($ext in '.md','.html'){
    $dest = "$destPath$ext"
    $lp = Join-Path $localDocs ($base + $ext)
    if(Test-Path $lp){ Copy-Item $lp $dest -Force }
    else {
      curl.exe -fLsS "$RepoRaw/docs/$base$ext" -A (UA) -o $dest
      if($LASTEXITCODE -ne 0){ Log "ERROR: documentation download failed: $base$ext"; exit 1 }
    }
  }
}
PlaceDoc 'START-HERE.md'            (Join-Path $Root 'START-HERE')                                  'Offline Emergency Kit - Start Here'
PlaceDoc 'I-NEED-TO.md'             (Join-Path $Root 'I-NEED-TO')                                   'I need to - Emergency Quick Index'
PlaceDoc 'EMERGENCY-ESSENTIALS.md'  (Join-Path $Root 'EMERGENCY-ESSENTIALS')                        'Emergency essentials - print this one page'
PlaceDoc 'POWER-AND-DEVICES.md'     (Join-Path $Root 'POWER-AND-DEVICES')                           'Power and devices'
PlaceDoc 'HOW-TO-RUN-OFFLINE-AI.md' (Join-Path $Root 'AI-Offline\HOW-TO-RUN-OFFLINE-AI')            'Offline AI - How To Run'
PlaceDoc 'HOW-TO-ASK-YOUR-DOCS.md'  (Join-Path $Root 'AI-Offline\DocReader-GPT4All\HOW-TO-ASK-YOUR-DOCS') 'Ask Your Documents - GPT4All'
PlaceDoc 'HOW-TO-TRANSLATE.md'      (Join-Path $Root 'AI-Offline\HOW-TO-TRANSLATE')                 'Offline translator - How To'
PlaceDoc 'HOW-TO-USE-KIWIX.md'      (Join-Path $Root 'Kiwix-Reader\HOW-TO-USE-KIWIX')               'How to Use Kiwix'
PlaceDoc 'Manuals-READ-ME-FIRST.md' (Join-Path $Root 'Manuals\READ-ME-FIRST')                       'Manuals - Read Me First'
PlaceDoc 'Medical-READ-ME-FIRST.md' (Join-Path $Root 'Medical\READ-ME-FIRST')                       'Medical - Read Me First'
PlaceDoc 'PSYCHOLOGICAL-FIRST-AID.md' (Join-Path $Root 'Medical\PSYCHOLOGICAL-FIRST-AID')            'Psychological first aid - helping people cope'
PlaceDoc 'RADIO-GUIDE.md'           (Join-Path $Root 'Manuals\Radio-Communications\RADIO-GUIDE')     'Emergency Radio Communications Guide'
PlaceDoc 'RADIO-FREQUENCIES.md'     (Join-Path $Root 'Manuals\Radio-Communications\RADIO-FREQUENCIES') 'Radio Frequency Reference'
PlaceDoc 'HOW-TO-VIEW-MAPS.md'      (Join-Path $Root 'OsmAnd\HOW-TO-VIEW-MAPS')                      'Offline Maps - How to View'
PlaceDoc 'MAP-AND-COMPASS.md'       (Join-Path $Root 'OsmAnd\MAP-AND-COMPASS')                       'Map and compass - navigation without a device'
PlaceDoc 'USE-ON-PHONE.md'          (Join-Path $Root 'Phone-Apps\USE-ON-PHONE')                      'Use the Library on a Phone'
PlaceDoc 'Education-READ-ME-FIRST.md' (Join-Path $Root 'Education\READ-ME-FIRST')                     'Education - Khan Academy Offline'
PlaceDoc 'HOW-TO-KOLIBRI.md'          (Join-Path $Root 'Education\HOW-TO-KOLIBRI')                     'Kolibri - Offline Learning App'

# ================================================================ README index
# CHECK-DRIVE scripts (#28), placed before the index so README.html lists them.
foreach($f in 'CHECK-DRIVE.sh','check-drive.ps1','CHECK-DRIVE.bat'){
  $dest = Join-Path $Root $f
  $lp = Join-Path (Join-Path $scriptDir 'drive') $f
  if(Test-Path $lp){ Copy-Item $lp $dest -Force }
  else {
    curl.exe -fLsS "$RepoRaw/drive/$f" -A (UA) -o $dest
    if($LASTEXITCODE -ne 0){ Log "ERROR: download failed: drive/$f"; exit 1 }
  }
}
# A raw download is the LF git copy; cmd.exe wants CRLF. The .sh must stay LF.
$bat = Join-Path $Root 'CHECK-DRIVE.bat'
[System.IO.File]::WriteAllText($bat, (([System.IO.File]::ReadAllText($bat) -replace "`r", '') -replace "`n", "`r`n"), [System.Text.Encoding]::ASCII)
Copy-Item (Join-Path $Root 'CHECK-DRIVE.sh') (Join-Path $Root 'CHECK-DRIVE.command') -Force   # macOS double-click

Log '=== Building README.html (full index of everything) ==='
function Esc2($s){ $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' }
function Rel2($full){ ($full.Substring($Root.Length)).TrimStart('\','/') -replace '\\','/' }
function Nice2($name){ ($name -replace '\.[A-Za-z0-9]+$','') -replace '[-_]',' ' }
function Human2($b){ if($b -ge 1GB){"{0:N2} GB" -f ($b/1GB)}elseif($b -ge 1MB){"{0:N0} MB" -f ($b/1MB)}else{"{0:N0} KB" -f ($b/1KB)} }
$idxCss = @'
<style>:root{--bg:#0f1420;--card:#171f2e;--ink:#e7ecf3;--muted:#9fb0c3;--accent:#4fd1c5;--accent2:#f6ad55;--line:#273246;--code:#0b0f17}@media(prefers-color-scheme:light){:root{--bg:#f4f6fb;--card:#fff;--ink:#15202b;--muted:#56657a;--accent:#0d9488;--accent2:#b45309;--line:#e2e8f0;--code:#f1f5f9}}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.65 -apple-system,Segoe UI,Roboto,Arial,sans-serif}.wrap{max-width:1000px;margin:0 auto;padding:28px 20px 80px}h1{font-size:30px;background:linear-gradient(135deg,var(--accent),var(--accent2));-webkit-background-clip:text;background-clip:text;color:transparent}h2{font-size:21px;border-bottom:2px solid var(--line);padding-bottom:6px;margin-top:32px}a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}code{background:var(--code);padding:2px 6px;border-radius:6px;font-family:Consolas,monospace;font-size:13px}table{border-collapse:collapse;width:100%;margin:10px 0;font-size:14.5px}th,td{border:1px solid var(--line);padding:8px 11px;text-align:left;vertical-align:top}th{background:rgba(127,127,127,.12)}.muted{color:var(--muted);font-size:13px}.hero{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 20px;margin:14px 0}</style>
'@
try{
  $all = Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue
  $htmlDocs = $all | Where-Object {$_.Extension -eq '.html' -and $_.Name -ne 'README.html'} | Sort-Object {Rel2 $_.FullName}
  $mdDocs   = $all | Where-Object {$_.Extension -eq '.md'} | Sort-Object {Rel2 $_.FullName}
  $pdfs     = $all | Where-Object {$_.Extension -eq '.pdf'} | Sort-Object {Rel2 $_.FullName}
  $zims     = $all | Where-Object {$_.Extension -eq '.zim'} | Sort-Object {Rel2 $_.FullName}
  $apks     = $all | Where-Object {$_.Extension -eq '.apk'} | Sort-Object {Rel2 $_.FullName}
  $progs    = $all | Where-Object {$e=$_.Extension.ToLower(); ($e -in @('.bat','.sh','.command','.appimage','.run','.dmg')) -or ($e -eq '.exe' -and $_.Name -match 'installer|kiwix-desktop')} | Sort-Object {Rel2 $_.FullName}
  $data     = $all | Where-Object {$_.Name -like '*.bz2' -or $_.Name -like '*.obf.zip'} | Sort-Object {Rel2 $_.FullName}
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("<!DOCTYPE html><html lang=`"en`"><head><meta charset=`"utf-8`"><meta name=`"viewport`" content=`"width=device-width,initial-scale=1`"><title>Offline Emergency Library - Full Index</title>$idxCss</head><body><div class=`"wrap`">")
  [void]$sb.Append("<h1>&#128703; Offline Emergency Library &mdash; Full Index</h1>")
  [void]$sb.Append("<div class='hero'>Every guide, document, manual, archive, app and data file on this drive, with links.<br><span class='muted'>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')</span></div>")
  if(Test-Path (Join-Path $Root 'START-HERE.html')){ [void]$sb.Append("<p>&#128073; New here? Start with <a href='START-HERE.html'><b>START-HERE.html</b></a>.</p>") }
  [void]$sb.Append("<h2>&#128214; Guides &amp; Documentation</h2><table><tr><th>Guide</th><th>Folder</th><th>Open</th></tr>")
  foreach($h in $htmlDocs){ $rel=Rel2 $h.FullName; $dir=Split-Path $rel -Parent; if(-not $dir){$dir='(root)'}; $mdRel=$rel -replace '\.html$','.md'; $mdLink=if(Test-Path (Join-Path $Root $mdRel)){" &middot; <a href='$mdRel'>md</a>"}else{''}; [void]$sb.Append("<tr><td>$(Esc2 (Nice2 $h.Name))</td><td class='muted'>$dir</td><td><a href='$rel'>HTML</a>$mdLink</td></tr>") }
  [void]$sb.Append("</table>")
  if($pdfs){ [void]$sb.Append("<h2>&#128218; Manuals &amp; Books (PDF)</h2><table><tr><th>Document</th><th>Folder</th><th>Size</th><th>Open</th></tr>"); foreach($p in $pdfs){ $rel=Rel2 $p.FullName; [void]$sb.Append("<tr><td>$(Esc2 (Nice2 $p.Name))</td><td class='muted'>$(Split-Path $rel -Parent)</td><td>$(Human2 $p.Length)</td><td><a href='$rel'>PDF</a></td></tr>") }; [void]$sb.Append("</table>") }
  if($zims){ [void]$sb.Append("<h2>&#127760; Offline Archives (ZIM &mdash; open with Kiwix)</h2><table><tr><th>Archive</th><th>Folder</th><th>Size</th><th>File</th></tr>"); foreach($z in $zims){ $rel=Rel2 $z.FullName; [void]$sb.Append("<tr><td>$(Esc2 (Nice2 $z.Name))</td><td class='muted'>$(Split-Path $rel -Parent)</td><td>$(Human2 $z.Length)</td><td><a href='$rel'>open</a></td></tr>") }; [void]$sb.Append("</table>") }
  if($progs){ [void]$sb.Append("<h2>&#9881; Programs &amp; Launchers</h2><table><tr><th>Item</th><th>Folder</th></tr>"); foreach($x in $progs){ $rel=Rel2 $x.FullName; $dir=Split-Path $rel -Parent; if(-not $dir){$dir='(root)'}; [void]$sb.Append("<tr><td><a href='$rel'>$(Esc2 $x.Name)</a></td><td class='muted'>$dir</td></tr>") }; [void]$sb.Append("</table>") }
  if($apks){ [void]$sb.Append("<h2>&#128241; Phone Apps (Android APK)</h2><table><tr><th>App</th><th>Folder</th><th>Size</th></tr>"); foreach($a in $apks){ $rel=Rel2 $a.FullName; [void]$sb.Append("<tr><td><a href='$rel'>$(Esc2 $a.Name)</a></td><td class='muted'>$(Split-Path $rel -Parent)</td><td>$(Human2 $a.Length)</td></tr>") }; [void]$sb.Append("</table>") }
  if($data){ [void]$sb.Append("<h2>&#128451; Data</h2><table><tr><th>Item</th><th>Folder</th><th>Size</th></tr>"); foreach($d in ($data|Where-Object{$_.Name -like '*.bz2'})){ $rel=Rel2 $d.FullName; [void]$sb.Append("<tr><td>$(Esc2 $d.Name) <span class='muted'>(Wikipedia)</span></td><td class='muted'>$(Split-Path $rel -Parent)</td><td>$(Human2 $d.Length)</td></tr>") }; $maps=$data|Where-Object{$_.Name -like '*.obf.zip'}; if($maps){ $sum=($maps|Measure-Object Length -Sum).Sum; [void]$sb.Append("<tr><td>Offline US maps - $($maps.Count) files</td><td class='muted'>OsmAnd</td><td>$(Human2 $sum)</td></tr>") }; [void]$sb.Append("</table>") }
  [void]$sb.Append("</div></body></html>")
  [System.IO.File]::WriteAllText((Join-Path $Root 'README.html'), $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
  Log "README.html index written."
}catch{ Log "README index ERROR: $($_.Exception.Message)" }

# ================================================================ drive check (#28)
# One SHA-256 line per file, so CHECK-DRIVE can find damage later. Runs last, after README.html.
# Format (same on every OS): "<lowercase sha256>  ./path/with/forward/slashes", byte-sorted, LF, UTF-8.
Log '=== Drive check list: CHECKSUMS-SHA256.txt ==='
Log 'Hashing every file (one pass over the whole drive - this can take a while)...'
$skipNames = '^(CHECKSUMS-SHA256\.txt.*|_download\.log|_filelist\.txt|_index\.xml|.*\.part|.*\.aria2|\._.*|\.DS_Store)$'
$skipDirs  = '^(\.Spotlight-V100|\.fseventsd|\.Trashes|System Volume Information)/'
$rootFull = (Get-Item -LiteralPath $Root).FullName.TrimEnd('\','/')
$sumLines = New-Object System.Collections.Generic.List[string]
$hashFail = New-Object System.Collections.Generic.List[string]
foreach($fi in (Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force -ErrorAction SilentlyContinue)){
  $rel = $fi.FullName.Substring($rootFull.Length).TrimStart('\','/') -replace '\\','/'
  if($fi.Name -match $skipNames -or $rel -match $skipDirs){ continue }
  try { $h = (Get-FileHash -LiteralPath $fi.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower(); $sumLines.Add("$h  ./$rel") }
  catch { $hashFail.Add($rel) }
}
if($hashFail.Count){ Log "ERROR: could not read these files for the checksum list: $($hashFail -join ', ')"; exit 1 }
# Byte (ordinal) order of the path, the same order as LC_ALL=C sort on macOS/Linux.
$arr = $sumLines.ToArray(); $keys = [string[]]@($arr | ForEach-Object { $_.Substring(66) })
[System.Array]::Sort($keys, $arr, [System.StringComparer]::Ordinal)
$text = if($arr.Count){ ($arr -join "`n") + "`n" } else { '' }
$listNew = Join-Path $Root 'CHECKSUMS-SHA256.txt.new'
[System.IO.File]::WriteAllText($listNew, $text, (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $listNew (Join-Path $Root 'CHECKSUMS-SHA256.txt') -Force
Log "CHECKSUMS-SHA256.txt: $($arr.Count) files. Run CHECK-DRIVE every few months."

# ================================================================ self-check (#30)
# Read-only checks of what was built, so a broken kit never ends with a bare DONE.
# Writes nothing to the drive (CHECKSUMS-SHA256.txt above stays correct).
Log '=== Self-check ==='
$scFail = 0
function ScPass($m){ Log "  PASS  $m" }
function ScWarn($m){ Log "  WARN  $m" }
function ScFail($m){ Log "  FAIL  $m"; $script:scFail++ }
$e = Join-Path $Root 'AI-Offline\engine'
$build = Join-Path $e 'BUILD.txt'
# 1. Every engine folder has its program (a failed unpack leaves a folder empty).
if(Test-Path $build){
  $miss = @()
  foreach($d in $LlamaAssets.Values){
    $t = if($d -in 'x64','arm64','vulkan-x64'){ 'llama-cli.exe' } else { 'llama-cli' }
    $dir = Join-Path $e $d
    if(-not ((Test-Path $dir) -and (Get-ChildItem $dir -Recurse -File -Filter $t -ErrorAction SilentlyContinue | Select-Object -First 1))){ $miss += $d }
  }
  if(-not $miss){ ScPass "AI engine $((Get-Content $build -TotalCount 1).Trim()) is on the drive for all 8 platforms" }
  else { ScFail "AI engine program missing in engine\: $($miss -join ' ') (re-run the installer)" }
} else { ScFail 'AI engine was not downloaded (see the [1/8] lines above)' }
# 2. The engine starts on this computer: the x64 program the .bat launchers use.
if($env:OS -eq 'Windows_NT'){
  $exe = Join-Path $e 'x64\llama-cli.exe'
  if(Test-Path $exe){
    $out = @(& $exe --version 2>&1 | ForEach-Object { "$_" }); $rc = $LASTEXITCODE
    if($rc -eq 0){
      $v = ($out | Where-Object { $_ -match 'version:' } | Select-Object -First 1)
      ScPass "AI engine starts on this computer (x64): $v"
    } else {
      ScFail "AI engine does not start on this computer (x64): exit code $rc"
      if($rc -eq -1073741515){ Log '        A DLL is missing (0xC0000135). If a file is missing from engine\x64, re-run the installer. Otherwise install the Microsoft Visual C++ Redistributable (x64) and run the AI again.' }
    }
  } elseif(Test-Path $build) { Log '  (engine start test skipped: no engine\x64\llama-cli.exe, see the FAIL above)' }
} else { ScWarn 'engine start test skipped: not Windows (run get-offline-library.sh to test a Mac/Linux engine)' }
# 3. Every ZIM has the ZIM magic number and its full size. The header says where the
#    file's closing 16-byte MD5 starts, so a cut-off download is caught. (A file of the
#    right size with damaged insides is not: that needs a full read.)
$zims = @(Get-ChildItem $Root -Recurse -File -Filter *.zim -ErrorAction SilentlyContinue)
$zbad = @()
foreach($z in $zims){
  $ok = $false
  try{
    $fs = [System.IO.File]::OpenRead($z.FullName)
    try{ $b = New-Object byte[] 80; $n = $fs.Read($b,0,80); $len = $fs.Length } finally { $fs.Close() }
    $ok = ($n -eq 80) -and $b[0] -eq 0x5A -and $b[1] -eq 0x49 -and $b[2] -eq 0x4D -and $b[3] -eq 4 -and
          (([decimal][System.BitConverter]::ToUInt64($b,72)) + 16) -eq [decimal]$len
  } catch { $ok = $false }
  if(-not $ok){ $zbad += (Rel2 $z.FullName) }
}
if(-not $zims){ ScWarn 'no Kiwix archives (.zim) found' }
elseif(-not $zbad){ ScPass "$($zims.Count) Kiwix archives (.zim): header and size OK" }
else { ScFail ("Kiwix archive(s) not a ZIM or not complete - delete each one and re-run the installer:`n        " + ($zbad -join "`n        ")) }
# 4. Every PDF starts with %PDF.
$pdfs = @(Get-ChildItem $Root -Recurse -File -Filter *.pdf -ErrorAction SilentlyContinue)
$pbad = @()
foreach($f in $pdfs){
  $head = ''
  try{ $fs = [System.IO.File]::OpenRead($f.FullName); try{ $b = New-Object byte[] 4; $n = $fs.Read($b,0,4); $head = [System.Text.Encoding]::ASCII.GetString($b,0,$n) } finally { $fs.Close() } } catch { $head = '' }
  if($head -ne '%PDF'){ $pbad += (Rel2 $f.FullName) }
}
if(-not $pdfs){ ScWarn 'no PDF manuals found' }
elseif(-not $pbad){ ScPass "$($pdfs.Count) PDF files: all start with %PDF" }
else { ScFail ("file(s) named .pdf that are not PDFs - delete each one and re-run the installer:`n        " + ($pbad -join "`n        ")) }

if($scFail -eq 0){
  Log '=== DONE. Open README.html (full index) or START-HERE.html ==='
  Write-Host ''
  Write-Host "  Finished. Your offline library is in: $Root" -ForegroundColor Green
  Write-Host "  Open README.html for a full index, or START-HERE.html to begin." -ForegroundColor Green
} else {
  Log "=== FINISHED WITH PROBLEMS: $scFail self-check(s) failed - see the FAIL lines above ==="
  Write-Host ''
  Write-Host "  Your offline library is in: $Root" -ForegroundColor Yellow
  Write-Host "  Fix the FAIL line(s) above before you rely on it." -ForegroundColor Yellow
  exit 1
}

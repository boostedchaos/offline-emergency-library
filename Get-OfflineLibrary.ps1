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
  [switch]$SkipWikipedia,   # Wikipedia is the biggest default download (~53 GB); allow skipping
  [switch]$SkipMaps,        # OsmAnd maps (~17 GB for US); allow skipping
  [switch]$SkipModels,      # the large AI chat models (~11 GB)
  [switch]$Education,        # OPT-IN: add Khan Academy (Kiwix ZIM, ~168 GB with videos)
  [string]$EduLang = 'en'    # Khan Academy language: en, es, or fr
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$RepoRaw = 'https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main'
$Continents = @('africa','asia','australia-oceania','centralamerica','europe','northamerica','southamerica')

# ---------------------------------------------------------------- -ListRegions (discovery, no download)
if($ListRegions){
  $tmp = Join-Path $env:TEMP 'osmand_idx.xml'
  curl.exe -s 'https://download.osmand.net/get_indexes' -o $tmp
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
function Fetch($url,$out){ curl.exe -L -C - --retry 10 --retry-delay 5 --retry-all-errors -s -o $out $url }
function UA(){ 'Mozilla/5.0' }

# free-space check (needs roughly 60 GB for everything)
try {
  $drive = (Get-Item $Root).PSDrive
  $freeGB = [math]::Round((Get-PSDrive $drive.Name).Free/1GB,1)
  Log "Destination: $Root   (free space: $freeGB GB)"
  if ($freeGB -lt 92) { Log "WARNING: ~92 GB recommended for the full library. You have $freeGB GB free. Consider -SkipWikipedia / -SkipMaps / -SkipModels." }
} catch {}

# ---------------------------------------------------------------- folder tree
$dirs = @(
 'AI-Offline','AI-Offline\engine','AI-Offline\models','AI-Offline\DocReader-GPT4All',
 'Manuals','Manuals\ArmyFieldManuals','Manuals\Repair-iFixit','Manuals\DIY-Appropedia',
 'Manuals\Survival-Water-Food','Manuals\Radio-Communications',
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
Log '=== [1/8] Offline AI engine (llama.cpp, CPU + GPU) ==='
try{
  $rel = Gh-ReleaseWith 'ggml-org/llama.cpp' 'bin-win-cpu-x64'
  if($rel){
    foreach($pat in @('bin-win-cpu-x64\.zip$','bin-win-cpu-arm64\.zip$','bin-win-vulkan-x64\.zip$')){
      $a = $rel.assets | Where-Object { $_.name -match $pat } | Select-Object -First 1
      if($a){
        $zip = Join-Path $Root ("AI-Offline\engine\"+$a.name)
        Log "engine: $($a.name)"; Fetch $a.browser_download_url $zip
        $sub = if($a.name -match 'arm64'){'arm64'} elseif($a.name -match 'vulkan'){'vulkan-x64'} else {'x64'}
        try{ Expand-Archive $zip -DestinationPath (Join-Path $Root "AI-Offline\engine\$sub") -Force }catch{ Log "  extract failed: $($_.Exception.Message)" }
      }
    }
  } else { Log 'engine: no suitable llama.cpp release found' }
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

# ================================================================ 3. GPT4All
Log '=== [3/8] GPT4All (offline document Q&A) ==='
try{
  $rel = Gh-ReleaseWith 'nomic-ai/gpt4all' 'installer-win64-v'
  $a = $rel.assets | Where-Object { $_.name -match 'installer-win64-v.*\.exe$' -and $_.name -notmatch 'arm' } | Select-Object -First 1
  if($a){ Log "gpt4all: $($a.name)"; Fetch $a.browser_download_url (Join-Path $Root "AI-Offline\DocReader-GPT4All\$($a.name)") }
}catch{ Log "gpt4all ERROR: $($_.Exception.Message)" }

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
 @{id='bwb_S0-EJI-512';                                      n='Where There Is No Doctor.pdf';                    d='Medical\Manuals-PDF'}
 @{id='where-there-is-no-dentist-13th-printing-2010';        n='Where There Is No Dentist.pdf';                   d='Medical\Manuals-PDF'}
 @{id='shipsmedicineche0000medi';                            n='Ships Medicine Chest and First Aid at Sea.pdf';   d='Medical\Manuals-PDF'}
)
foreach($p in $pdfs){
  try{
    $meta = curl.exe -sL "https://archive.org/metadata/$($p.id)" -A (UA) | ConvertFrom-Json
    $f = $meta.files | Where-Object {$_.name -match '\.pdf$' -and $_.name -notmatch '_text\.pdf$'} | Sort-Object {[double]$_.size} -Descending | Select-Object -First 1
    if($f){ Log "pdf: $($p.n)"; Fetch "https://archive.org/download/$($p.id)/$([uri]::EscapeDataString($f.name))" (Join-Path $Root "$($p.d)\$($p.n)") }
    else { Log "pdf: NO PDF for $($p.id)" }
  }catch{ Log "pdf ERROR $($p.n): $($_.Exception.Message)" }
}

# ================================================================ 7. Wikipedia + Maps
if(-not $SkipWikipedia){
  # Kiwix ZIM (full article text, no images): opens in Kiwix and is searchable.
  # The raw XML dump (enwiki-...pages-articles.xml.bz2) cannot be opened by Kiwix.
  Log '=== [7/8] Wikipedia (full article text, Kiwix ZIM, ~53 GB) ==='
  $wdir = 'https://download.kiwix.org/zim/wikipedia/'
  $wname = Latest-Zim $wdir 'wikipedia_en_all_nopic_'
  if($wname){ Log "zim: $wname"; Fetch ($wdir+$wname) (Join-Path $Root "Wikipedia\$wname") }
  else { Log 'zim: NOT FOUND for prefix wikipedia_en_all_nopic_' }
} else { Log '=== [7/8] Wikipedia SKIPPED ===' }

if(-not $SkipMaps){
  Log "=== [8/8] Offline maps (OsmAnd) - region: $Region ==="
  try{
    $idxFile = Join-Path $env:TEMP 'osmand_idx.xml'
    curl.exe -s 'https://download.osmand.net/get_indexes' -o $idxFile
    [xml]$idx = Get-Content $idxFile
    $allmaps = $idx.osmand_regions.region | Where-Object { $_.type -eq 'map' }
    # resolve the -Region tokens (comma/space separated) to a file set
    $tokens = ($Region -split '[,; ]') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
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
      foreach($r in $sel){
        $out = Join-Path $Root "OsmAnd\$($r.name)"
        Fetch "https://download.osmand.net/download.php?standard=yes&file=$($r.name)" $out
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
    Fetch 'https://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip' $mc
    Expand-Archive $mc -DestinationPath (Join-Path $mvd 'app') -Force
    # if the zip nested everything in a single subfolder, pull it up to \app
    if(-not (Test-Path (Join-Path $mvd 'app\OsmAndMapCreator.bat'))){
      $inner = Get-ChildItem (Join-Path $mvd 'app') -Directory | Select-Object -First 1
      if($inner -and (Test-Path (Join-Path $inner.FullName 'OsmAndMapCreator.bat'))){
        Get-ChildItem $inner.FullName -Force | Move-Item -Destination (Join-Path $mvd 'app') -Force
      }
    }
    $jz = Join-Path $mvd 'jre.zip'
    Log 'mapviewer: portable Java runtime'
    Fetch 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse' $jz
    $tmp = Join-Path $mvd '_jre_tmp'
    if(Test-Path $tmp){ Remove-Item $tmp -Recurse -Force }
    Expand-Archive $jz -DestinationPath $tmp -Force
    $jreSrc = Get-ChildItem $tmp -Directory | Select-Object -First 1
    $jreDst = Join-Path $mvd 'jre'
    if(Test-Path $jreDst){ Remove-Item $jreDst -Recurse -Force }
    if($jreSrc){ Move-Item $jreSrc.FullName $jreDst }
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
cd /d "%~dp0app"
call OsmAndMapCreator.bat
pause
"@
  Set-Content -Path (Join-Path $mvd 'VIEW-MAPS-ON-PC.bat') -Value $mvbat -Encoding ascii
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
Log '=== Writing launchers (.bat) ==='
function WriteBat($path,$text){ Set-Content -Path $path -Value $text -Encoding ascii }
$ao = Join-Path $Root 'AI-Offline'
WriteBat (Join-Path $ao 'CHAT-3B-light.bat') @"
@echo off
title Offline AI - Llama 3.2 3B (light)
cd /d "%~dp0"
"%~dp0engine\x64\llama-cli.exe" -m "%~dp0models\Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096 -cnv
pause
"@
WriteBat (Join-Path $ao 'CHAT-8B-smart.bat') @"
@echo off
title Offline AI - Llama 3.1 8B (smart)
cd /d "%~dp0"
"%~dp0engine\x64\llama-cli.exe" -m "%~dp0models\Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" -c 4096 -cnv
pause
"@
WriteBat (Join-Path $ao 'CHAT-GPU-Qwen7B.bat') @"
@echo off
title Offline AI - Qwen2.5 7B (GPU)
cd /d "%~dp0"
echo If this errors with out-of-memory, your GPU is too small - change -ngl 99 to a lower
echo number (e.g. -ngl 20) or use a CPU launcher instead.
"%~dp0engine\vulkan-x64\llama-cli.exe" -m "%~dp0models\Qwen2.5-7B-Instruct-Q4_K_M.gguf" -c 4096 -ngl 99 -cnv
pause
"@
WriteBat (Join-Path $ao 'WEB-UI.bat') @"
@echo off
title Offline AI - Web UI
cd /d "%~dp0"
echo When it says "server listening", open a browser to http://127.0.0.1:8080
"%~dp0engine\x64\llama-server.exe" -m "%~dp0models\Llama-3.2-3B-Instruct-Q4_K_M.gguf" -c 4096 --host 127.0.0.1 --port 8080
pause
"@

# ================================================================ documentation
Log '=== Documentation (Markdown + HTML) ==='
# doc source: local .\docs if present (repo clone), else download pre-rendered files from GitHub raw
$scriptDir = if($PSScriptRoot){$PSScriptRoot}else{(Get-Location).Path}
$localDocs = Join-Path $scriptDir 'docs'
function Get-Doc($name){
  $lp = Join-Path $localDocs $name
  if(Test-Path $lp){ return (Get-Content $lp -Raw) }
  try { return (curl.exe -sL "$RepoRaw/docs/$name" -A (UA)) } catch { return $null }
}
# both .md and .html ship in the repo /docs; just place them (no conversion needed)
function PlaceDoc($srcName,$destPath,$title){
  $base = $srcName -replace '\.md$',''
  foreach($ext in '.md','.html'){
    $c = Get-Doc ($base + $ext)
    if($c){ [System.IO.File]::WriteAllText("$destPath$ext",$c,[System.Text.UTF8Encoding]::new($false)) }
    else { Log "  doc missing: $base$ext" }
  }
}
PlaceDoc 'START-HERE.md'            (Join-Path $Root 'START-HERE')                                  'Offline Emergency Kit - Start Here'
PlaceDoc 'HOW-TO-RUN-OFFLINE-AI.md' (Join-Path $Root 'AI-Offline\HOW-TO-RUN-OFFLINE-AI')            'Offline AI - How To Run'
PlaceDoc 'HOW-TO-ASK-YOUR-DOCS.md'  (Join-Path $Root 'AI-Offline\DocReader-GPT4All\HOW-TO-ASK-YOUR-DOCS') 'Ask Your Documents - GPT4All'
PlaceDoc 'HOW-TO-USE-KIWIX.md'      (Join-Path $Root 'Kiwix-Reader\HOW-TO-USE-KIWIX')               'How to Use Kiwix'
PlaceDoc 'Manuals-READ-ME-FIRST.md' (Join-Path $Root 'Manuals\READ-ME-FIRST')                       'Manuals - Read Me First'
PlaceDoc 'Medical-READ-ME-FIRST.md' (Join-Path $Root 'Medical\READ-ME-FIRST')                       'Medical - Read Me First'
PlaceDoc 'RADIO-GUIDE.md'           (Join-Path $Root 'Manuals\Radio-Communications\RADIO-GUIDE')     'Emergency Radio Communications Guide'
PlaceDoc 'HOW-TO-VIEW-MAPS.md'      (Join-Path $Root 'OsmAnd\HOW-TO-VIEW-MAPS')                      'Offline Maps - How to View'
PlaceDoc 'USE-ON-PHONE.md'          (Join-Path $Root 'Phone-Apps\USE-ON-PHONE')                      'Use the Library on a Phone'
PlaceDoc 'Education-READ-ME-FIRST.md' (Join-Path $Root 'Education\READ-ME-FIRST')                     'Education - Khan Academy Offline'

# ================================================================ README index
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

Log '=== DONE. Open README.html (full index) or START-HERE.html ==='
Write-Host ''
Write-Host "  Finished. Your offline library is in: $Root" -ForegroundColor Green
Write-Host "  Open README.html for a full index, or START-HERE.html to begin." -ForegroundColor Green

# Offline source-pair regression. No inference or external downloads.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('doc-qa-' + [guid]::NewGuid().ToString('N'))
$src = Join-Path $tmp 'source'
$psRoot = Join-Path $tmp 'powershell drive'
$shRoot = Join-Path $tmp 'bash drive'
$utf8 = New-Object Text.UTF8Encoding($false)
function Require($condition, $message){ if(-not $condition){ throw $message } }
function Log($message){ Write-Host $message }
function Fetch($url, $out){ throw "Unexpected network access: $url -> $out" }
try {
  New-Item -ItemType Directory -Force (Join-Path $src 'doc-qa\text') | Out-Null
  foreach($file in 'index.html','reader.css','reader.mjs','START-DOCS.bat','start-docs.sh'){
    Copy-Item (Join-Path $repo "doc-qa\$file") (Join-Path $src "doc-qa\$file")
  }
  $rows = @()
  foreach($entry in @(
    @('Manuals/ArmyFieldManuals/Army.pdf','a','MD5','excerpts','Army pressure bandage source'),
    @('Medical/Manuals-PDF/Medical.pdf','b','SHA256','pages',"Medical wound source`fNext PDF page")
  )){
    $pdf,$id,$algorithm,$mode,$content = $entry
    $payload = [Text.Encoding]::UTF8.GetBytes("%PDF-test-$id")
    foreach($root in $psRoot,$shRoot){
      $path = Join-Path $root $pdf
      New-Item -ItemType Directory -Force (Split-Path $path -Parent) | Out-Null
      [IO.File]::WriteAllBytes($path, $payload)
    }
    $text = Join-Path $src "doc-qa\text\$id.txt"
    [IO.File]::WriteAllText($text, $content, $utf8)
    $pdfHash = (Get-FileHash -LiteralPath (Join-Path $psRoot $pdf) -Algorithm $algorithm).Hash.ToLowerInvariant()
    $textHash = (Get-FileHash -LiteralPath $text -Algorithm SHA256).Hash.ToLowerInvariant()
    $rows += "$pdf`t$algorithm`t$pdfHash`ttext/$id.txt`t$textHash`t$mode`tFixture"
  }
  [IO.File]::WriteAllText((Join-Path $src 'doc-qa\sources.tsv'), ($rows -join "`n") + "`n", $utf8)
  . (Join-Path $repo 'doc-qa\install.ps1')
  $bash = Join-Path ${env:ProgramFiles} 'Git\bin\bash.exe'
  Require (Test-Path -LiteralPath $bash) 'Git Bash is required'
  $runner = Join-Path $tmp 'run-install.sh'
  [IO.File]::WriteAllText($runner, @'
set -eu
. "$3/doc-qa/install.sh"
log(){ :; }
fetch(){ echo "Unexpected network access" >&2; return 44; }
install_manual_qa "$1" "$2"
'@, $utf8)
  function RunBash($root){
    & $bash $runner ($root -replace '\\','/') ($src -replace '\\','/') ($repo -replace '\\','/')
    return $LASTEXITCODE
  }
  $rc = Install-ManualQA $psRoot $src
  Require ($rc -eq 0) 'PowerShell rejected valid PDF/text pairs'
  Require ((RunBash $shRoot) -eq 0) 'Bash rejected valid PDF/text pairs'
  $relative = 'AI-Offline\Manual-QA'
  $expected = @($rows | ForEach-Object { $f=$_.Split("`t"); "$($f[0])`ttext/$($f[4]).txt`t$($f[5])" }) -join "`n"
  foreach($root in $psRoot,$shRoot){
    $ready = [IO.File]::ReadAllText((Join-Path $root "$relative\ready.tsv")).Trim()
    Require ($ready -ceq $expected) 'Ready sources did not preserve both fixture documents'
  }
  foreach($file in 'index.html','reader.css','reader.mjs','START-DOCS.bat','start-docs.sh','start-docs.command','ready.tsv','missing.txt'){
    Require ((Get-FileHash (Join-Path $psRoot "$relative\$file")).Hash -eq
             (Get-FileHash (Join-Path $shRoot "$relative\$file")).Hash) "Installer mismatch: $file"
  }
  Write-Host 'PASS: both helpers install identical validated sources without network access'

  # A rerun must reject changed PDFs and remove old sources from the ready list.
  foreach($root in $psRoot,$shRoot){
    [IO.File]::WriteAllText((Join-Path $root 'Medical\Manuals-PDF\Medical.pdf'), '%PDF-new-edition', $utf8)
  }
  Require ((Install-ManualQA $psRoot $src) -eq 1) 'PowerShell accepted a stale medical text pair'
  Require ((RunBash $shRoot) -eq 1) 'Bash accepted a stale medical text pair'
  $global:LASTEXITCODE = 0   # expected failure above must not become this script's exit code
  foreach($root in $psRoot,$shRoot){
    $ready = [IO.File]::ReadAllText((Join-Path $root "$relative\ready.tsv")).Trim()
    Require ($ready -ceq $expected.Split("`n")[0]) 'Stale medical source remained searchable'
    Require ([IO.File]::ReadAllText((Join-Path $root "$relative\missing.txt")).Contains('Medical.pdf')) 'Missing source was not reported'
  }
  Write-Host 'PASS: a changed PDF is excluded and a rerun retains no stale index row'

  $moved = Join-Path $tmp 'moved here\Library copy'
  New-Item -ItemType Directory -Force (Split-Path $moved -Parent) | Out-Null
  Move-Item -LiteralPath $psRoot -Destination $moved
  Require ((Install-ManualQA $moved $src) -eq 1) 'Moved drive changed source-pair validation'
  $ready = [IO.File]::ReadAllText((Join-Path $moved "$relative\ready.tsv"))
  Require ($ready -notmatch [regex]::Escape($tmp)) 'Source index contains an absolute build path'
  Require ($ready.Trim() -ceq $expected.Split("`n")[0]) 'Moved drive lost its valid source'
  Write-Host 'PASS: validated source paths survive relocation to a path with spaces'
  exit 0
}
finally {
  if(Test-Path -LiteralPath $tmp){ Remove-Item -LiteralPath $tmp -Recurse -Force }
}

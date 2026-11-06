# Called by Get-OfflineLibrary.ps1 with its existing Fetch and Log helpers.
function DocQa-Download($url, $target) {
  # The installer's Fetch stops the whole run on failure; optional source text must not.
  $part = "$target.new"
  Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
  & curl.exe -fL --retry 5 --retry-all-errors --retry-delay 3 -sS -o $part $url 2>$null
  if($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $part) -and (Get-Item $part).Length -gt 0){
    Move-Item -LiteralPath $part -Destination $target -Force; return $true
  }
  Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
  return $false
}
function Install-ManualQA($Root, $SourceDir) {
  $out = Join-Path $Root 'AI-Offline\Manual-QA'
  New-Item -ItemType Directory -Force (Join-Path $out 'text') | Out-Null
  $base = 'https://raw.githubusercontent.com/elhajahmadj/offline-emergency-library/main/doc-qa'
  foreach($name in 'index.html','reader.css','reader.mjs','START-DOCS.bat','start-docs.sh','sources.tsv'){
    $local = Join-Path $SourceDir "doc-qa\$name"
    $target = Join-Path $out $name
    if(Test-Path -LiteralPath $local){ Copy-Item -LiteralPath $local -Destination $target -Force }
    else {
      if(-not (DocQa-Download "$base/$name" $target)){ throw "Document reader asset unavailable: $name" }
    }
  }
  Copy-Item -LiteralPath (Join-Path $out 'start-docs.sh') -Destination (Join-Path $out 'start-docs.command') -Force   # macOS double-click
  $bat = Join-Path $out 'START-DOCS.bat'
  [IO.File]::WriteAllText($bat, ([IO.File]::ReadAllText($bat) -replace "`r", '' -replace "`n", "`r`n"), [Text.Encoding]::ASCII)
  $ready = @(); $missing = @()
  foreach($line in [IO.File]::ReadAllLines((Join-Path $out 'sources.tsv'))){
    if(-not $line -or $line.StartsWith('#')){ continue }
    $f = $line.Split("`t")
    if($f.Count -ne 7){ throw 'Invalid document source manifest' }
    $pdf,$algorithm,$pdfHash,$url,$textHash,$mode,$unused = $f
    if($pdf -notmatch '^(Medical/Manuals-PDF|Manuals/ArmyFieldManuals)/[^/\\]+\.pdf$' -or $pdf.Contains('..') -or
       $algorithm -notin @('MD5','SHA256') -or $textHash -notmatch '^[a-f0-9]{64}$' -or $mode -notin @('pages','excerpts')){
      throw 'Unsafe document source manifest'
    }
    $path = Join-Path $Root $pdf
    if(-not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm $algorithm).Hash.ToLowerInvariant() -ne $pdfHash){
      $missing += "$pdf - PDF missing or changed; text needs refreshing"
      continue
    }
    $text = Join-Path $out "text\$textHash.txt"
    if(-not (Test-Path -LiteralPath $text) -or (Get-FileHash -LiteralPath $text -Algorithm SHA256).Hash.ToLowerInvariant() -ne $textHash){
      if(Test-Path -LiteralPath $text){ Remove-Item -LiteralPath $text -Force }
      if($url.StartsWith('text/')){
        $local = Join-Path $SourceDir "doc-qa\$url"
        if(Test-Path -LiteralPath $local){ Copy-Item -LiteralPath $local -Destination $text }
        else { [void](DocQa-Download "$base/$url" $text) }
      } elseif($url.StartsWith('https://archive.org/download/')){
        [void](DocQa-Download $url $text)
      } else { throw 'Unexpected document text host' }
    }
    if(-not (Test-Path -LiteralPath $text) -or (Get-FileHash -LiteralPath $text -Algorithm SHA256).Hash.ToLowerInvariant() -ne $textHash){
      $missing += "$pdf - source text download failed or changed"
      continue
    }
    $ready += "$pdf`ttext/$textHash.txt`t$mode"
  }
  $utf8 = New-Object Text.UTF8Encoding($false)
  [IO.File]::WriteAllText((Join-Path $out 'ready.tsv'), (($ready -join "`n") + "`n"), $utf8)
  [IO.File]::WriteAllText((Join-Path $out 'missing.txt'), $(if($missing){ ($missing -join "`n") + "`n" } else { '' }), $utf8)
  foreach($message in $missing){ Log "doc-QA WARN: $message" }
  Log "doc-QA: $($ready.Count) manuals ready; $($missing.Count) unavailable. Open AI-Offline\Manual-QA\START-DOCS.bat."
  return $missing.Count
}

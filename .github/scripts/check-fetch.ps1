# Exercise the installer's real Fetch in Windows PowerShell 5.1 without network access.
# A malformed native executable reproduces Windows refusing to launch a downloader.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$src = [IO.File]::ReadAllText((Join-Path $repo 'Get-OfflineLibrary.ps1'))
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$tokens, [ref]$errors)
if($errors){ throw $errors }
$fetch = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Fetch' }, $true)
if(-not $fetch){ throw 'Fetch function not found' }
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('oel-fetch-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tmp | Out-Null
try {
  $payload = Join-Path $tmp 'payload.txt'
  [IO.File]::WriteAllText($payload, 'offline library download fixture')
  $url = ([uri]$payload).AbsoluteUri
  # The executable fixture implements only aria's output placement and exit outcomes.
  $stub = Join-Path $tmp 'stub.exe'
  Add-Type -OutputAssembly $stub -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.IO;
public class AriaFixture {
  public static int Main(string[] args) {
    string dir = "", name = "";
    for (int i = 0; i < args.Length - 1; i++) {
      if (args[i] == "-d") dir = args[i + 1];
      if (args[i] == "-o") name = args[i + 1];
    }
    string mode = Environment.GetEnvironmentVariable("OEL_FETCH_MODE");
    string output = Path.Combine(dir, name);
    if (mode == "cancel") return 7;
    if (mode == "partial") {
      File.WriteAllText(output, "unfinished");
      File.WriteAllText(output + ".aria2", "resume");
      return 1;
    }
    if (mode == "missing") return 0;
    if (mode == "failure") return 1;
    File.Copy(new Uri(args[args.Length - 1]).LocalPath, output, true);
    return 0;
  }
}
'@
  $cases = @(
    @{ Name='blocked-aria-stale-zero'; Mode='blocked'; Stale=0; Exit=0; Bytes=$true; Fallback=$true },
    @{ Name='blocked-aria-stale-three'; Mode='blocked'; Stale=3; Exit=0; Bytes=$true; Fallback=$true },
    # On a PC with Smart App Control on, Windows can block the unsigned stub aria2c.exe
    # built above. Fetch then falls back to curl, so aria-success fails locally with
    # 'wrong fallback behavior'. That is the #132 fix working, not a regression (#140).
    @{ Name='aria-success'; Mode='success'; Stale=3; Exit=0; Bytes=$true; Fallback=$false },
    @{ Name='aria-missing-output'; Mode='missing'; Stale=0; Exit=0; Bytes=$true; Fallback=$true },
    @{ Name='aria-nonzero'; Mode='failure'; Stale=0; Exit=0; Bytes=$true; Fallback=$true },
    @{ Name='aria-cancel'; Mode='cancel'; Stale=0; Exit=1; Bytes=$false; Fallback=$false },
    @{ Name='aria-partial'; Mode='partial'; Stale=0; Exit=1; Bytes=$false; Fallback=$false },
    @{ Name='blocked-curl-existing-file'; Mode='curl'; Stale=0; Exit=1; Bytes=$false; Fallback=$false }
  )
  foreach($case in $cases){
    $dir = Join-Path $tmp $case.Name
    New-Item -ItemType Directory $dir | Out-Null
    $out = Join-Path $dir 'download.txt'
    $aria = Join-Path $dir 'aria2c.exe'
    if($case.Mode -eq 'blocked'){ [IO.File]::WriteAllText($aria, 'MZ invalid executable') }
    else { Copy-Item $stub $aria }
    if($case.Mode -eq 'curl'){
      [IO.File]::WriteAllText((Join-Path $dir 'curl.exe'), 'MZ invalid executable')
      [IO.File]::WriteAllText($out, 'old file must not imply success')
    }
    # Use curl from its installed PATH location; copying only the exe can separate
    # a runner's curl from the DLLs it needs. Only the blocked-curl case shadows it.
    $runner = Join-Path $dir 'run.ps1'
    $body = @"
`$ErrorActionPreference = 'Continue'
`$env:PATH = '$($dir.Replace("'", "''"));' + `$env:PATH
`$env:OEL_FETCH_MODE = '$($case.Mode)'
`$UseAria = `$$($case.Mode -ne 'curl')
`$DlTty = `$false
function Log(`$m){ Write-Host `$m }
$($fetch.Extent.Text)
`$global:LASTEXITCODE = $($case.Stale)
Fetch '$($url.Replace("'", "''"))' '$($out.Replace("'", "''"))'
exit 0
"@
    [IO.File]::WriteAllText($runner, $body)
    $ErrorActionPreference = 'Continue' # expected native launch errors arrive on stderr
    $text = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner 2>&1 | Out-String)
    $rc = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Write-Host "== $($case.Name) (exit $rc)"
    Write-Host $text
    if($rc -ne $case.Exit){ throw "$($case.Name): expected exit $($case.Exit), got $rc" }
    if($case.Bytes -and (-not (Test-Path $out) -or [IO.File]::ReadAllText($out) -cne [IO.File]::ReadAllText($payload))){
      throw "$($case.Name): payload missing or incorrect"
    }
    if(($text -match 'falling back to curl') -ne $case.Fallback){ throw "$($case.Name): wrong fallback behavior" }
    if($case.Mode -eq 'partial' -and ([IO.File]::ReadAllText($out) -cne 'unfinished' -or -not (Test-Path "$out.aria2"))){
      throw 'partial file or resume control was changed'
    }
    Write-Host "PASS: $($case.Name)"
  }
  $global:LASTEXITCODE = 0 # expected child failures must not fail the calling CI shell
  Write-Host 'Fetch regression checks: OK'
}
finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
  if(Test-Path $tmp){ throw "cleanup failed: $tmp" }
  Write-Host "Cleanup OK: $tmp"
}

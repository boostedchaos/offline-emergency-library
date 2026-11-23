#!/usr/bin/env bash
# A web page in the kit whose source is down must not stop the install, and the end-of-run
# self-check must say so (#298). Runs both installers' real get_html_doc / Get-HtmlDoc and the
# real self-check block 4b against a local server. fetch / Fetch are stand-ins with one try
# (check-changed-source.sh and check-fetch.ps1 test the real ones).
# Needs bash, curl, python3 and pwsh. Used by CI (lint job). OEL_PS=powershell.exe uses Windows PowerShell 5.1.
set -u
cd "$(dirname "$0")/../.." || exit 1
PS="${OEL_PS:-pwsh}"
T="$(mktemp -d)"; SRV=""; trap '[ -z "$SRV" ] || kill "$SRV" 2>/dev/null; rm -rf "$T"' EXIT
die(){ echo "FAIL: $*"; exit 1; }
wp(){ cygpath -w "$1" 2>/dev/null || printf '%s' "$1"; }
PY=""; for c in python3 python; do "$c" -c 'import http.server' >/dev/null 2>&1 && { PY="$c"; break; }; done
[ -n "$PY" ] || die "python3 not found"
NAME='Emergency Childbirth (US Civil Defense).html'
# the real code under test
for f in remote_size fetch_sized html_ok html_imgs get_html_doc; do
  awk -v f="$f" '!on && $0 ~ "^"f"\\(\\)" {on=1; print; if (/\}([ ]+#.*)?$/) exit; next} on {print} on && /^}/ {exit}' get-offline-library.sh
done > "$T/code.sh"
for f in remote_size fetch_sized html_ok html_imgs get_html_doc; do grep -q "^$f()" "$T/code.sh" || die "$f not found in get-offline-library.sh"; done
sed -n '/^# 4b\. The Emergency Childbirth/,/^# 5\. /p' get-offline-library.sh | sed '$d' > "$T/sc.sh"
grep -q sc_fail "$T/sc.sh" || die "self-check block 4b not found in get-offline-library.sh"
cat > "$T/run.ps1" <<'PSEOF'
param($base, $root, $installer)
$src = [IO.File]::ReadAllText($installer) -replace "`r`n", "`n"
$ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)
foreach($n in 'UA','Remote-Size','Fetch-Sized','Html-Ok','Html-Imgs','Get-HtmlDoc'){
  $f = $ast.Find({ param($a) $a -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq $n }, $true)
  if(-not $f){ Write-Output "FAIL: $n not found in Get-OfflineLibrary.ps1"; exit 2 }
  Invoke-Expression $f.Extent.Text
}
$sc = [regex]::Match($src, '(?ms)^# 4b\. The Emergency Childbirth.*?(?=^# 5\. )')
if(-not $sc.Success){ Write-Output 'FAIL: self-check block 4b not found in Get-OfflineLibrary.ps1'; exit 2 }
if($IsLinux -or $IsMacOS){ $c = (Get-Command curl -CommandType Application | Select-Object -First 1).Source; function curl.exe { & $c @args } }
function Log($m){ Write-Output "log $m" }
function Fetch($url, $out, [switch]$Soft){
  curl.exe -fsL -o $out $url
  if($LASTEXITCODE -ne 0){ if($Soft){ throw 'download failed' }; Write-Output 'fetch ended the run'; exit 1 }
}
function ScPass($s){ Write-Output "PASS  $s" }; function ScWarn($s){ Write-Output "WARN  $s" }; function ScFail($s){ Write-Output "FAIL  $s" }
$Root = $root; $Only = ''
Get-HtmlDoc $base 'page.html' 'Emergency Childbirth (US Civil Defense).html' (Join-Path $Root (Join-Path 'Medical' 'Emergency-Childbirth'))
Write-Output 'RUN-WENT-ON'
$ast2 = $sc.Value; if($IsLinux -or $IsMacOS){ $ast2 = $ast2.Replace('\', '/') }
Invoke-Expression $ast2
PSEOF
run_sh(){ # base drive
  ( set +u; ROOT="$2"; ONLY=""; UA=test; log(){ echo "log $*"; }
    . "$T/code.sh"
    fetch(){ curl -fsL -o "$2" "$1" || { echo 'fetch ended the run'; exit 1; }; }
    sc_pass(){ echo "PASS  $*"; }; sc_warn(){ echo "WARN  $*"; }; sc_fail(){ echo "FAIL  $*"; }
    get_html_doc "$1" page.html "$NAME" "$ROOT/Medical/Emergency-Childbirth"
    echo RUN-WENT-ON
    . "$T/sc.sh" ) 2>&1
}
run_ps(){ "$PS" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(wp "$T/run.ps1")" "$1" "$(wp "$2")" "$(wp "$PWD/Get-OfflineLibrary.ps1")" 2>&1 | tr -d '\r'; }
cat > "$T/srv.py" <<'PYEOF'
import sys, http.server
def page(v): return ('<!DOCTYPE html>\n<html><body>%s<img src="images/a.jpg"><img src="images/b.jpg"></body></html>\n' % v).encode()
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_HEAD(self): self.go(False)
    def do_GET(self): self.go(True)
    def go(self, send):
        mode, name = self.path.strip('/').split('/', 1)
        code, body = 200, b'picture'
        if name == 'page.html':
            body = page('edition two, longer ' if mode == 'new' else 'one ')
            if mode == 'cut': body = body[:50]                    # a whole answer, half a page
            if mode == 'text': body = b'We are down for maintenance.'
        elif mode == 'noimg' and name.endswith('b.jpg'): code = 404
        if mode == 'down': code = 503
        if code != 200: body = b'error'
        self.send_response(code); self.send_header('Content-Length', str(len(body))); self.end_headers()
        if send: self.wfile.write(body)
s = http.server.HTTPServer(('127.0.0.1', 0), H)
open(sys.argv[1], 'w').write(str(s.server_address[1])); s.serve_forever()
PYEOF
"$PY" "$(wp "$T/srv.py")" "$(wp "$T/port")" > "$T/srv.log" 2>&1 & SRV=$!
for _ in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done
[ -s "$T/port" ] || die "test HTTP server did not start: $(cat "$T/srv.log")"
U="http://127.0.0.1:$(cat "$T/port")"
fail=0
new_drive(){ for d in sh ps; do rm -rf "$T/$d"; mkdir -p "$T/$d/Medical/Emergency-Childbirth"; done; }
check(){ # name mode self-check-regex [text the page on the drive must hold; '-' = no page]
  for d in sh ps; do
    if [ "$d" = sh ]; then o="$(run_sh "$U/$2" "$T/sh")"; else o="$(run_ps "$U/$2" "$T/ps")"; fi
    f="$T/$d/Medical/Emergency-Childbirth/$NAME"; why=""
    printf '%s\n' "$o" | grep -q '^RUN-WENT-ON$' || why="the run did not go on"
    [ -n "$why" ] || printf '%s\n' "$o" | grep -qE "$3" || why="self-check line does not match /$3/"
    case "${4:-}" in
      "") ;;
      -) [ ! -e "$f" ] || why="a page was left on the drive" ;;
      *) grep -q "$4" "$f" 2>/dev/null || why="the page on the drive does not hold '$4'" ;;
    esac
    ls "$T/$d/Medical/Emergency-Childbirth/"*.new >/dev/null 2>&1 && why="a .new file was left"
    if [ -z "$why" ]; then echo "  OK   [$1] $d"; else echo "FAIL [$1] $d: $why"; printf '%s\n' "$o" | sed 's/^/    /'; fail=1; fi
  done
}
OKLINE='^PASS  Emergency Childbirth guide'
new_drive; check "source down, empty drive" down '^FAIL  .*missing: the page - re-run' -
check "source up again" up "$OKLINE" 'one '
check "source down, page on the drive" down "$OKLINE" 'one '
check "maintenance text, page on the drive" text "$OKLINE" 'one '
check "half a page, page on the drive" cut "$OKLINE" 'one '
check "new edition" new "$OKLINE" 'edition two'
for d in sh ps; do head -c 60 "$T/$d/Medical/Emergency-Childbirth/$NAME" > "$T/h" && cp "$T/h" "$T/$d/Medical/Emergency-Childbirth/$NAME"; done
check "half a page on the drive, source down" down '^FAIL  .*missing: the page - re-run'
check "half a page on the drive, source up" up "$OKLINE" 'one '
new_drive; check "one picture missing at the source" noimg '^FAIL  .*missing: images/b\.jpg - re-run' 'one '
new_drive; check "half a page, empty drive" cut '^FAIL  .*missing: the page' -
[ "$fail" = 0 ] && echo "HTML page checks: OK"
exit "$fail"

#!/usr/bin/env bash
# A publisher can replace a PDF or model under the same URL. A re-run must then fetch the
# new file whole, never resume it onto the old copy (#274). Runs both installers' real
# download helpers against a local file:// source, offline, in seconds.
set -u
cd "$(dirname "$0")/../.."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
p="$(cd "$T" && { pwd -W 2>/dev/null || pwd; })"
case "$p" in /*) URL="file://$p/src/manual.pdf" ;; *) URL="file:///$p/src/manual.pdf" ;; esac
mkdir -p "$T/src" "$T/sh" "$T/ps"
put(){ { printf '%%PDF-%s\n' "$1"; head -c "$2" /dev/zero | tr '\0' "$3"; } > "$T/src/manual.pdf"; }

# --- bash: the real fetch, remote_size, fetch_sized, fetch_remote and get_pdf_url
for f in fetch remote_size fetch_sized fetch_remote get_pdf_url; do
  # A one-line function ends on its own line; a longer one at the first line that is "}".
  awk -v f="$f" '!on && $0 ~ "^"f"\\(\\)" {on=1; print; if (/; }$/) exit; next} on {print} on && /^}/ {exit}' get-offline-library.sh
done > "$T/helpers.sh"
for f in fetch remote_size fetch_sized fetch_remote get_pdf_url; do
  grep -q "^$f()" "$T/helpers.sh" || { echo "FAIL: $f not found in get-offline-library.sh"; exit 1; }
done
sh_run(){ ( USE_ARIA=0; DL_TTY=0; UA=test; log(){ echo "$*"; }; sleep(){ :; }; . "$T/helpers.sh"; get_pdf_url "$URL" manual.pdf "$T/sh" ) > "$T/sh.log" 2>&1; }

# --- PowerShell: the real Fetch, Remote-Size, Fetch-Sized and Fetch-Remote
cat > "$T/run.ps1" <<'EOF'
param($url, $out)
$ErrorActionPreference = 'Stop'
$src = [IO.File]::ReadAllText($env:OEL_INSTALLER)
$ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)
foreach($n in 'Fetch','UA','Remote-Size','Fetch-Sized','Fetch-Remote'){
  $f = $ast.Find({ param($a) $a -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq $n }, $true)
  if(-not $f){ Write-Host "FAIL: $n not found in Get-OfflineLibrary.ps1"; exit 2 }
  Invoke-Expression $f.Extent.Text
}
# Off Windows there is no curl.exe; point the installer's calls at curl.
if($IsLinux -or $IsMacOS){ $c = (Get-Command curl -CommandType Application | Select-Object -First 1).Source; function curl.exe { & $c @args } }
$UseAria = $false; $DlTty = $false
function Log($m){ Write-Host $m }
function Start-Sleep{}
Fetch-Remote $url $out
exit 0
EOF
PS=""; command -v pwsh >/dev/null 2>&1 && PS=pwsh
[ -z "$PS" ] && command -v powershell.exe >/dev/null 2>&1 && PS=powershell.exe
ps_path(){ cygpath -w "$1" 2>/dev/null || printf '%s' "$1"; }
ps_run(){ OEL_INSTALLER="$(ps_path "$PWD/Get-OfflineLibrary.ps1")" "$PS" -NoProfile -ExecutionPolicy Bypass -File "$(ps_path "$T/run.ps1")" "$URL" "$(ps_path "$T/ps/manual.pdf")" > "$T/ps.log" 2>&1; }

check(){ # name [file the drive copy must equal; default: the source]
  want="${2:-$T/src/manual.pdf}"
  if ! sh_run; then echo "FAIL [$1] bash: exited non-zero"; sed 's/^/    /' "$T/sh.log"; fail=1
  elif cmp -s "$want" "$T/sh/manual.pdf" && ! ls "$T"/sh/*.part >/dev/null 2>&1; then echo "  OK   [$1] bash"
  else echo "FAIL [$1] bash: drive copy differs from the source"; fail=1; fi
  [ -z "$PS" ] && return
  if ! ps_run; then echo "FAIL [$1] PowerShell: exited non-zero"; sed 's/^/    /' "$T/ps.log"; fail=1
  elif cmp -s "$want" "$T/ps/manual.pdf" && ! ls "$T"/ps/*.part >/dev/null 2>&1; then echo "  OK   [$1] PowerShell"
  else echo "FAIL [$1] PowerShell: drive copy differs from the source"; fail=1; fi
}
put v1 200 a; check "first download"
put v2 600 b; check "publisher replaced it with a bigger file"
put v3 50 c;  check "publisher replaced it with a smaller file"
check "unchanged re-run"
[ -z "$PS" ] && echo "  skip PowerShell half: no pwsh or powershell.exe"

# A failed HEAD (error page, or a redirect hop with its own length) must not be taken as the
# file's size: a correct copy on the drive stays and the run exits 0 (#289). Needs a real HTTP
# server, since a file:// source cannot answer with a status. When HEAD gives no size, the
# helpers ask for one byte and read a 206's Content-Range total; the 500 mode is a host that
# refuses HEAD (as iris.who.int does), and 500norange also ignores Range, so no size is known.
PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && "$c" -c 'import http.server' >/dev/null 2>&1 && { PY="$c"; break; }; done
if [ -z "$PY" ]; then echo "  skip HEAD-error cases: no python3"; else
  cat > "$T/srv.py" <<'EOF'
import re, sys, http.server
asked = {}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_HEAD(self):
        body = open(sys.argv[1], 'rb').read()
        mode = self.path.split('/')[1]
        if mode == '503': self.send_response(503); self.send_header('Content-Length', '170')
        elif mode in ('500', '500norange'): self.send_response(500)  # no length, as iris.who.int
        elif mode == '405': self.send_response(405); self.send_header('Content-Length', '150')
        elif mode == '302': self.send_response(302); self.send_header('Location', '/ok/manual.pdf'); self.send_header('Content-Length', '95')
        elif mode in ('len', 'wait', 'drop', 'dropnorange', 'drop503', 'down'): self.send_response(200); self.send_header('Content-Length', str(len(body)))
        else: self.send_response(200)  # a 200 that states no length
        self.end_headers()
    def do_GET(self):
        body = open(sys.argv[1], 'rb').read()  # read per request: a case replaces the file
        mode = self.path.split('/')[1]
        r = self.headers.get('Range', '')      # honor 'bytes=N-' and 'bytes=0-0' like a real server, so a resume shows
        open(sys.argv[3], 'a').write('GET %s %s\n' % (mode, r or '-'))
        n = asked[mode] = asked.get(mode, 0) + 1
        if mode == 'down' or (mode == 'wait' and n % 2) or (mode == 'drop503' and n % 3 == 2):   # 503; 'wait' asks for a pause, once per shell
            self.send_response(503); self.send_header('Content-Length', '0')
            if mode != 'drop503': self.send_header('Retry-After', '25' if mode == 'wait' else '2')
            self.end_headers(); return
        if (mode == 'drop' and not r) or (mode in ('dropnorange', 'drop503') and n % 3 == 1):  # cut off half way
            self.send_response(200); self.send_header('Content-Length', str(len(body))); self.end_headers()
            self.wfile.write(body[:len(body) // 2]); self.wfile.flush(); self.close_connection = True; return
        m = re.match(r'bytes=(\d+)-(\d*)$', r) if mode not in ('500norange', 'dropnorange') else None
        s = int(m.group(1)) if m else 0
        e = min(int(m.group(2)), len(body) - 1) if m and m.group(2) else len(body) - 1
        if m and s < len(body) and s <= e and (s, e) != (0, len(body) - 1):
            self.send_response(206); self.send_header('Content-Range', 'bytes %d-%d/%d' % (s, e, len(body)))
            self.send_header('Content-Length', str(e + 1 - s)); self.end_headers(); self.wfile.write(body[s:e + 1])
        else:
            self.send_response(200); self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
s = http.server.HTTPServer(('127.0.0.1', 0), H)
open(sys.argv[2], 'w').write(str(s.server_address[1]))
s.serve_forever()
EOF
  put v4 5000 d
  "$PY" "$T/srv.py" "$T/src/manual.pdf" "$T/port" "$T/req.log" > "$T/srv.log" 2>&1 &
  SRV=$!; trap 'kill $SRV 2>/dev/null; rm -rf "$T"' EXIT
  for _ in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done
  if [ ! -s "$T/port" ]; then echo "FAIL: test HTTP server did not start"; sed 's/^/    /' "$T/srv.log"; fail=1; else
    for m in 503 405 302; do
      URL="http://127.0.0.1:$(cat "$T/port")/$m/manual.pdf"
      cp "$T/src/manual.pdf" "$T/sh/manual.pdf"; cp "$T/src/manual.pdf" "$T/ps/manual.pdf"
      check "HEAD answers $m, correct copy on the drive"
    done
    # The publisher replaced the file with a bigger one, the HEAD fails and the server ignores
    # Range, so no size is known: the older copy on the drive must stay whole, never be resumed
    # into a mix of both editions (#289). The one-byte probe is the only GET: no download.
    P="http://127.0.0.1:$(cat "$T/port")"; nsh=1; [ -n "$PS" ] && nsh=2
    cp "$T/src/manual.pdf" "$T/old.pdf"; put v5 6000 e; : > "$T/req.log"
    URL="$P/500norange/manual.pdf"; check "HEAD answers 500, Range ignored, older copy on the drive" "$T/old.pdf"
    g="$(grep -c '^GET 500norange ' "$T/req.log")"; g0="$(grep -c '^GET 500norange bytes=0-0$' "$T/req.log")"
    if [ "$g" = "$nsh" ] && [ "$g0" = "$nsh" ]; then echo "  OK   [Range ignored: one one-byte probe per shell, no download]"
    else echo "FAIL [Range ignored: expected $nsh GET bytes=0-0, got:]"; sed 's/^/    /' "$T/req.log"; fail=1; fi
    # A host that refuses HEAD but honors Range (iris.who.int) gives the size through the one-byte
    # probe, so the new edition replaces the older copy ...
    URL="$P/500/manual.pdf"; check "HEAD answers 500, one-byte probe sizes it, new edition replaces the older copy"
    # ... and a working HEAD still does the same.
    put v6 7000 f
    URL="$P/len/manual.pdf"; check "HEAD works, new edition replaces the older copy"
    # With nothing on the drive, a failed HEAD still downloads the file whole, and a part file
    # left by an earlier sized download is removed once the file is in place (check fails on *.part):
    # sized by the probe ...
    rm -f "$T/sh/manual.pdf" "$T/ps/manual.pdf"
    printf 'stale' > "$T/sh/manual.pdf.4999.part"; printf 'stale' > "$T/ps/manual.pdf.4999.part"
    URL="$P/500/manual.pdf"; check "HEAD answers 500, empty drive"
    # ... or with no size at all (through <file>.unknown.part).
    rm -f "$T/sh/manual.pdf" "$T/ps/manual.pdf"
    printf 'stale' > "$T/sh/manual.pdf.4999.part"; printf 'stale' > "$T/ps/manual.pdf.4999.part"
    URL="$P/500norange/manual.pdf"; check "HEAD answers 500, Range ignored, empty drive"
    # fetch does its own retries (#298). A Retry-After must not hold the run (gutenberg.org asks for
    # 6 hours; 25 s here, and the pause between tries is off in this check) ...
    want_gets(){ # name mode expected-lines
      g="$(grep "^GET $2 " "$T/req.log" | tr '\n' ',')"; w="$3"; [ -n "$PS" ] && w="$3$3"
      if [ "$g" = "$w" ]; then echo "  OK   [$1: requests]"; else echo "FAIL [$1: requests] expected $w got $g"; fail=1; fi
    }
    fresh(){ rm -f "$T/sh/"* "$T/ps/"*; : > "$T/req.log"; }
    fresh; t0="$(date +%s)"; URL="$P/wait/manual.pdf"; check "503 with Retry-After, then up"
    t="$(( $(date +%s) - t0 ))"
    if [ "$t" -lt 20 ]; then echo "  OK   [Retry-After not waited for]"; else echo "FAIL [Retry-After waited for: ${t}s]"; fail=1; fi
    want_gets "Retry-After" wait "GET wait -,GET wait -,"
    # ... a download cut off half way resumes there ...
    h="$(( $(wc -c < "$T/src/manual.pdf") / 2 ))"
    fresh; URL="$P/drop/manual.pdf"; check "cut off half way"
    want_gets "cut off" drop "GET drop -,GET drop bytes=$h-,"
    # ... and keeps its part when the source is down in between (an error page is no reason to start over) ...
    fresh; URL="$P/drop503/manual.pdf"; check "cut off half way, then 503"
    want_gets "then 503" drop503 "GET drop503 -,GET drop503 bytes=$h-,GET drop503 bytes=$h-,"
    # ... or starts over, never joined, when the server ignores Range ...
    fresh; URL="$P/dropnorange/manual.pdf"; check "cut off half way, Range ignored"
    want_gets "Range ignored" dropnorange "GET dropnorange -,GET dropnorange bytes=$h-,GET dropnorange -,"
    # ... and a source that stays down is a failure after 11 tries, also with a half-done part file
    # on the drive (with --retry-max-time, curl 8.14.1 and 8.23.0 exit 0 there, curl/curl#23838).
    fresh; URL="$P/down/manual.pdf"; sz="$(wc -c < "$T/src/manual.pdf" | tr -d ' ')"
    for d in sh ps; do head -c "$h" "$T/src/manual.pdf" > "$T/$d/manual.pdf.$sz.part"; done
    down(){ # shell-name folder runner
      if "$3"; then echo "FAIL [source stays down] $1: exited 0"; fail=1
      elif [ -e "$T/$2/manual.pdf" ]; then echo "FAIL [source stays down] $1: half a file was kept as complete"; fail=1
      elif ! grep -q 'ERROR: download failed' "$T/$2.log"; then echo "FAIL [source stays down] $1: no ERROR line"; sed 's/^/    /' "$T/$2.log"; fail=1
      else echo "  OK   [source stays down] $1"; fi
    }
    down bash sh sh_run; [ -z "$PS" ] || down PowerShell ps ps_run
    n="$(grep -c "^GET down bytes=$h-\$" "$T/req.log")"
    if [ "$n" = "$(( 11 * nsh ))" ]; then echo "  OK   [source stays down: 11 tries per shell]"; else echo "FAIL [source stays down: $n tries, expected $(( 11 * nsh ))]"; fail=1; fi
  fi
fi

# The PDFs and models must go through the helper in both installers.
for pat in '^  fetch_remote "\$1" "\$out"' '^if \[ -z "\$ONLY" \]; then fetch_remote "\$M3B"' '^  fetch_remote "\$M8B"' '^  fetch_remote "\$MQ7"' '^  fetch_remote "\$MTR"'; do
  grep -qE "$pat" get-offline-library.sh || { echo "FAIL: get-offline-library.sh has no line matching: $pat"; fail=1; }
done
for pat in 'Fetch-Remote \$url \$out' 'Fetch-Remote \$m\.u' 'Fetch-Remote "https://huggingface\.co/bartowski/Qwen_Qwen3'; do
  grep -qE "$pat" Get-OfflineLibrary.ps1 || { echo "FAIL: Get-OfflineLibrary.ps1 has no line matching: $pat"; fail=1; }
done
[ "$fail" = 0 ] && echo "Changed-source checks: OK"
exit "$fail"

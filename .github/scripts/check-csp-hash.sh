#!/usr/bin/env bash
# CSP hash check: a page whose Content-Security-Policy allows its inline scripts by hash
# ('sha256-...') must list the hash of every inline script it has. When a script changes and
# its hash is not updated, the browser blocks it and the page silently stops working.
# Checks every tracked .html file with a CSP <meta> (or the files given as arguments).
# The hash is base64(sha256(script text as UTF-8)), as the browser computes it. CR LF is
# read as LF first, like the HTML parser does, so a CRLF (Windows) checkout passes too.
# Needs bash, git and perl. Used by CI (lint job).
set -u
cd "$(dirname "$0")/../.." || exit 1
if [ "$#" -gt 0 ]; then files=("$@")
else files=(); while IFS= read -r f; do files+=("$f"); done < <(git ls-files '*.html' | xargs grep -l 'http-equiv="Content-Security-Policy"'); fi
[ "${#files[@]}" -gt 0 ] || { echo "FAIL: no page with a Content-Security-Policy found"; exit 1; }

fail=0
for f in "${files[@]}"; do
  perl -MDigest::SHA=sha256_base64 -0777 -ne '
    my $f = $ARGV; my $fail = 0; s/\r\n?/\n/g;
    my ($csp) = /<meta http-equiv="Content-Security-Policy" content="([^"]*)"/i;
    defined $csp or do { print "FAIL: $f: no Content-Security-Policy meta\n"; exit 1 };
    my ($src) = $csp =~ /(?:^|;)\s*script-src\s([^;]*)/;
    defined $src or do { print "FAIL: $f: CSP has no script-src\n"; exit 1 };
    if ($src =~ /\x27unsafe-inline\x27/) { print "FAIL: $f: script-src still has \x27unsafe-inline\x27\n"; $fail = 1 }
    my $n = 0;
    while (/<script\b([^>]*)>(.*?)<\/script>/gs) {
      my ($attr, $body) = ($1, $2);
      next if $attr =~ /\bsrc\s*=/i;    # external file: not an inline script
      # A type that is not JavaScript (like text/xml data) is not run, so it needs no hash.
      if ($attr =~ /\btype\s*=\s*["\x27]?([^"\x27\s>]+)/i) { next unless $1 =~ m{^(text/javascript|application/javascript|text/ecmascript|application/ecmascript|module)$}i }
      $n++; my $h = sha256_base64($body) . "=";
      if (index($src, "\x27sha256-$h\x27") >= 0) { printf "ok: %s: script %d (%d bytes) sha256-%s\n", $f, $n, length($body), $h }
      else { printf "FAIL: %s: script %d (%d bytes) sha256-%s is not in script-src. Put \x27sha256-%s\x27 in the CSP.\n", $f, $n, length($body), $h, $h; $fail = 1 }
    }
    # A page can carry a CSP for inline styles only and load all its JavaScript from a file;
    # then there is no inline script to hash, and the rule below is trivially satisfied.
    if (!$n) { print "ok: $f: no inline script (nothing to hash)\n" }
    exit $fail;
  ' "$f" || fail=1
done
[ "$fail" = 0 ] || { echo "CSP script hash out of date. Fix the hash in the page (see above)."; exit 1; }

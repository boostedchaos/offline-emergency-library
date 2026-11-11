#!/usr/bin/env python3
"""Build the phone docs pack (#79): a small zip for on-device document-AI apps.

Contents:
  - every manual PDF in doc-qa/sources.tsv (the text-checked set the manual reader uses),
    fetched from the same source the installers use and checked against its recorded hash;
  - the phone-useful guides in GUIDES, as Markdown (document-AI apps import .md);
  - README.txt and LICENSES.txt (per-file attribution from sources.tsv).

Usage:
  build-phone-pack.py OUT.zip               download the PDFs
  build-phone-pack.py OUT.zip --from DRIVE  copy them from an installed drive instead
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
UA = "offline-emergency-library-phone-pack"
PACK_URL = ("https://github.com/elhajahmadj/offline-emergency-library/"
            "releases/download/phone-pack/Offline-Emergency-Phone-Pack.zip")
# Guides that make sense without the drive (no launchers, folders or desktop programs).
GUIDES = ["EMERGENCY-ESSENTIALS", "PSYCHOLOGICAL-FIRST-AID", "MAP-AND-COMPASS",
          "RADIO-GUIDE", "RADIO-FREQUENCIES", "POWER-AND-DEVICES"]

# Not public-release (FM 3-05.70: distribution restricted; FM 21-11: copyrighted AHA parts).
# The installer may fetch them for the user's own drive; this project must not host them.
DRIVE_ONLY = {"FM 3-05.70 Survival (2002).pdf", "Survival and First Aid for Soldiers.pdf"}
# Hostable, but left out to keep the pack small on mobile data (TM 9-243 is ~138 MB; #234).
TOO_BIG = {"TM 9-243 Use and Care of Hand Tools.pdf"}

README = f"""Offline Emergency Library - phone docs pack
=============================================

Survival, first-aid, medical, repair and food-growing manuals (PDF) plus short
emergency guides (Markdown), sized for a phone.

Use it:
  - Unzip it (Files app on iPhone/iPad; any file manager on Android).
  - Open the PDFs in any PDF reader, or import the PDFs and .md guides into an
    on-device document-AI app (for example NomadAI) and ask questions offline.

Medical books are references, not a substitute for a clinician.
Licenses: see LICENSES.txt. Some items are non-commercial: share this pack
free of charge only.

Latest version: {PACK_URL}
Project: https://github.com/elhajahmadj/offline-emergency-library
"""

LICENSE_NOTES = """
License terms
-------------
- US Army manuals: US government works, public domain. (Two Army manuals whose covers
  restrict distribution or carry copyrighted material are left out of this pack.)
- Other "Public domain" books: published before 1930, public domain in the US.
- A Practical Guide to Prolonged Casualty Care: (c) 2025 Henry M. Jackson Foundation,
  CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/ (included unchanged).
- WHO PDFs: (c) WHO, CC BY-NC-SA 3.0 IGO, https://creativecommons.org/licenses/by-nc-sa/3.0/igo/
  (included unchanged; no WHO endorsement implied; commercial use needs WHO permission).
- Hesperian (Where There Is No Doctor / Dentist): copies may be shared free or at
  cost, not for profit; see the copyright page inside each PDF.
- Guides/*.md: written by the Offline Emergency Library project, MIT license.

Because some items are non-commercial, this pack may only be shared free of charge.
"""


def sources():
    rows = []
    for line in (REPO / "doc-qa/sources.tsv").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            path, algo, digest, _, _, _, attribution = line.split("\t")
            rows.append((path, algo, digest, attribution))
    return rows


def installer_urls():
    """File name -> ('id', archive.org item) or ('url', direct link), from the bash installer."""
    out = {}
    text = (REPO / "get-offline-library.sh").read_text(encoding="utf-8")
    for kind, src, name in re.findall(r'^get_pdf(_url)? +"([^"]+)" +"([^"]+)"', text, re.M):
        out[name] = ("url" if kind else "id", src)
    return out


def get(url, retries=6, delay=20):
    # Retry transient failures - timeouts, 5xx, and the TLS connection drops archive.org hands
    # CI runners - but fail fast on a definite 4xx. curl's --retry-all-errors also retries a 404,
    # so a source that is really gone burned ~2 minutes (6 x 20 s) before failing; now a 4xx
    # stops on the first try with the URL in the error (#236). -L follows archive.org's redirect
    # to a data node; no -f, so we read the real status from -w and decide ourselves.
    last = ""
    for attempt in range(1, retries + 1):
        fd, tmp = tempfile.mkstemp()
        try:
            os.close(fd)
            r = subprocess.run(["curl", "-sSL", "--connect-timeout", "30", "--max-time", "600",
                                "-w", "%{http_code}", "-o", tmp, "-A", UA, url],
                               capture_output=True)
            code = r.stdout.decode(errors="replace").strip()
            if r.returncode == 0 and code.startswith("2"):
                return Path(tmp).read_bytes()
            if code.startswith("4"):          # item gone or moved - retrying will not help
                raise OSError(f"HTTP {code} for {url}")
            # With -L, if a hop after a redirect fails, curl exits non-zero but %{http_code}
            # still holds the redirect's 3xx - so key the message on curl's exit, not the code,
            # or a transport failure masquerades as "HTTP 302" and hides the real error (#236).
            last = (f"HTTP {code}" if r.returncode == 0
                    else f"curl exit {r.returncode} (last HTTP {code}): {r.stderr.decode(errors='replace').strip()}")
        finally:
            Path(tmp).unlink(missing_ok=True)
        if attempt == retries:
            raise OSError(f"{last} for {url} after {retries} tries")
        time.sleep(delay)


def resolve(kind, src):
    """Download URLs for one file, best first."""
    if kind == "url":
        return [src]
    # Same pick as the installer's ia_pdf: first .pdf that is not the OCR "_text.pdf".
    meta = json.loads(get(f"https://archive.org/metadata/{src}"))
    name = next(f["name"] for f in meta["files"]
                if f["name"].endswith(".pdf") and not f["name"].endswith("_text.pdf"))
    q = urllib.parse.quote(name)
    # From GitHub runners, archive.org/download/ often redirects to an eu.archive.org node
    # that never accepts the connection (curl exit 28 on every try), while the item's own
    # data nodes (d1/d2 in its metadata) answer. So try those first and the redirect last.
    nodes = [f"https://{meta[k]}{meta['dir']}/{q}" for k in ("d1", "d2") if meta.get(k) and meta.get("dir")]
    return nodes + [f"https://archive.org/download/{src}/{q}"]


def get_first(urls):
    for i, url in enumerate(urls):
        try:
            return get(url, retries=3)
        except OSError as e:
            if i == len(urls) - 1:
                raise
            print(f"  {e}; trying the next source", flush=True)


def main():
    args = sys.argv[1:]
    if len(args) not in (1, 3) or (len(args) == 3 and args[1] != "--from"):
        sys.exit(__doc__)
    out, drive = Path(args[0]), Path(args[2]) if len(args) == 3 else None
    tmp = out.with_suffix(".partial")
    try:
        build(tmp, drive)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise
    tmp.replace(out)  # never leave a half-written pack under the final name
    print(f"{out}: {out.stat().st_size / 1e6:.0f} MB")


def build(tmp, drive):
    urls = installer_urls()
    licenses = ["Files and attribution", "---------------------"]
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for path, algo, digest, attribution in sources():
            name = Path(path).name
            if name in DRIVE_ONLY or name in TOO_BIG:
                continue
            if drive:
                data = (drive / path).read_bytes()
            else:
                if name not in urls:
                    sys.exit(f"{name}: in sources.tsv but not downloaded by get-offline-library.sh")
                print(f"fetch: {name}", flush=True)
                data = get_first(resolve(*urls[name]))
            got = hashlib.new(algo.lower(), data).hexdigest()
            if got != digest:
                sys.exit(f"{name}: {algo} {got} does not match sources.tsv {digest}")
            z.writestr(f"Manuals/{name}", data)
            licenses.append(f"- Manuals/{name}: {attribution}")
        for g in GUIDES:
            z.write(REPO / "docs" / f"{g}.md", f"Guides/{g}.md")
            licenses.append(f"- Guides/{g}.md: MIT (this project)")
        z.writestr("README.txt", README)
        z.writestr("LICENSES.txt", "\n".join(licenses) + "\n" + LICENSE_NOTES)


if __name__ == "__main__":
    main()

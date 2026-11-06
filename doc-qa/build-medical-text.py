# /// script
# requires-python = ">=3.12"
# dependencies = ["pypdf[crypto]==7.0.0", "fonttools==4.68.0"]
# ///
"""Generate page-separated medical sidecars from the exact downloaded PDFs.

Developer maintenance only: uv run doc-qa/build-medical-text.py PDF_DIRECTORY
Never called by the library or its launchers. Review source editions and licenses
before changing the pinned PDF hashes below.
"""

from hashlib import sha256
from pathlib import Path
import sys

from pypdf import PdfReader


def main() -> None:
    """Verify source bytes, extract every page, and print manifest fields."""
    pdf_dir = Path(sys.argv[1])
    output = Path(__file__).parent / "text"
    output.mkdir(exist_ok=True)
    sources = (
        ("usuhs", "c1ff0011987cd4da0447c3bdf82b9e95f1d193640a2753616d078e1892ee2dbb",
         "A Practical Guide to Prolonged Casualty Care (USUHS-HJF, 2025), CC BY-NC-SA 4.0"),
        ("who-complications", "f472f20b1dd63f0fe5cddb20f43819d498184b58fe1d633474ab0818229a6b09",
         "WHO, Managing Complications in Pregnancy and Childbirth (2017), CC BY-NC-SA 3.0 IGO"),
        ("who-maternal", "f154bcc6206489dcab08f07114dc0ca2c45b0b26f136b898ace684379cd4e552",
         "WHO, Recommendations on Maternal Health (2025), CC BY-NC-SA 3.0 IGO"),
    )
    for name, expected, title in sources:
        pdf = pdf_dir / f"{name}.pdf"
        digest = sha256(pdf.read_bytes()).hexdigest()
        if digest != expected:
            raise SystemExit(f"{name}: PDF changed; review the edition and update its hash first")
        with pdf.open("rb") as stream:
            reader = PdfReader(stream)
            pages = [page.extract_text().replace("\f", " ").replace("\r\n", "\n") for page in reader.pages]
        # One header line travels with the file; the reader strips it so page numbers are unchanged.
        header = f"#SOURCE {title}. Non-commercial, share-alike; text extracted from the official PDF. See doc-qa/README.md.\n"
        text = (header + "\f".join(pages)).encode("utf-8")
        if not text.strip():
            raise SystemExit(f"{name}: no text extracted")
        (output / f"{name}.txt").write_bytes(text)
        print(f"{name}\t{digest}\t{sha256(text).hexdigest()}\t{len(pages)} pages")


if __name__ == "__main__":
    main()

from pathlib import Path
from pypdf import PdfReader

pdf_path = Path("tmp/docs/gemSpec_ZETA_1.4.0.pdf")
out_path = Path("tmp/docs/gemSpec_ZETA_1.4.0_fulltext.txt")

reader = PdfReader(str(pdf_path))

with out_path.open("w", encoding="utf-8") as f:
    for i, page in enumerate(reader.pages, start=1):
        text = (page.extract_text() or "").replace("\r", "")
        f.write(f"\n=== PAGE {i} ===\n")
        f.write(text)
        f.write("\n")

print(f"WROTE {out_path}")

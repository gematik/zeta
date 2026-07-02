from pathlib import Path
import re
from pypdf import PdfReader

pdf_path = Path("tmp/docs/gemSpec_ZETA_1.4.0.pdf")
out_path = Path("tmp/docs/gemSpec_ZETA_1.4.0_version_scan.txt")

terms = [
    r"policy engine input",
    r"\\bversion\\b",
    r"\\bver\\b",
    r"schemaVersion",
    r"contract v2",
    r"audience",
    r"resource",
    r"POST /v1/data/authz",
]
compiled = [re.compile(t, re.IGNORECASE) for t in terms]

reader = PdfReader(str(pdf_path))
results = []

for page_num, page in enumerate(reader.pages, start=1):
    text = (page.extract_text() or "").replace("\r", "")
    lines = text.split("\n")
    for idx, line in enumerate(lines):
        if any(p.search(line) for p in compiled):
            start = max(0, idx - 2)
            end = min(len(lines), idx + 3)
            ctx = "\n".join(lines[start:end])
            results.append((page_num, idx + 1, ctx))

with out_path.open("w", encoding="utf-8") as f:
    f.write(f"MATCHES {len(results)}\n")
    for page_num, line_num, ctx in results[:300]:
        f.write(f"\n=== PAGE {page_num} LINE {line_num} ===\n")
        f.write(ctx)
        f.write("\n---\n")

print(f"WROTE {out_path}")

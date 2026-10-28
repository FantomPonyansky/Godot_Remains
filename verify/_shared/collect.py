"""Collect verify/V-*/VERDICT.md into one table.

python verify/_shared/collect.py            print the table
python verify/_shared/collect.py --check    exit 1 if a row has no PASS/FAIL/PARTIAL
python verify/_shared/collect.py --write    also write verify/RESULTS.md
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ("PASS", "FAIL", "PARTIAL")


def field(text, name):
    m = re.search(r"^\|\s*%s\s*\|\s*(.*?)\s*\|\s*$" % re.escape(name), text, re.M)
    return m.group(1) if m else ""


def first_observation(text):
    _, _, rest = text.partition("## Observations")
    for line in rest.splitlines():
        line = line.strip()
        if line and not line.startswith("<"):
            return line
    return ""


def rows():
    for folder in sorted(ROOT.glob("V-*")):
        verdict = folder / "VERDICT.md"
        if not verdict.exists():
            yield folder.name, "", "", "no VERDICT.md"
            continue
        text = verdict.read_text(encoding="utf-8")
        result = field(text, "Result").upper()
        result = result if result in RESULTS else ""
        yield folder.name, result, field(text, "Date"), first_observation(text)


def main():
    table = ["| Row | Result | Date | Summary |", "|---|---|---|---|"]
    missing = []
    for name, result, date, note in rows():
        table.append("| %s | %s | %s | %s |" % (name, result or "—", date, note.replace("|", "/")))
        if not result:
            missing.append(name)
    out = "\n".join(table)
    print(out)
    if "--write" in sys.argv:
        (ROOT / "RESULTS.md").write_text("# Verify results\n\n" + out + "\n", encoding="utf-8")
    if "--check" in sys.argv and missing:
        print("\nNot judged: " + ", ".join(missing))
        sys.exit(1)


if __name__ == "__main__":
    main()

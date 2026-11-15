#!/usr/bin/env python3
"""Check relative Markdown links and the docs index.

Rules:
  1. Every relative link in README.md and docs/**.md must resolve to an
     existing path (anchors are stripped; external URLs are ignored).
  2. Every Markdown file under docs/ must be linked directly from
     docs/README.md, so the index is complete.

Exit 0 when both rules hold; exit 1 with a list of failures otherwise.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
INDEX = DOCS / "README.md"
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
EXTERNAL = ("http://", "https://", "mailto:", "#", "file://", "computer://")


def relative_targets(text: str):
    for raw in LINK.findall(text):
        target = raw.strip().split("#", 1)[0].strip()
        if not target or target.startswith(EXTERNAL):
            continue
        yield target


def markdown_files():
    files = [ROOT / "README.md"]
    if DOCS.exists():
        files.extend(sorted(DOCS.rglob("*.md")))
    return [f for f in files if f.exists()]


def check_links(files):
    checked = 0
    failures = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        for target in relative_targets(text):
            checked += 1
            if not (path.parent / target).resolve().exists():
                failures.append(f"{path.relative_to(ROOT)} -> {target}")
    return checked, failures


def check_index():
    if not INDEX.exists():
        return ["docs/README.md is missing"]
    text = INDEX.read_text(encoding="utf-8")
    linked = {(INDEX.parent / t).resolve() for t in relative_targets(text)}
    return [
        str(path.relative_to(ROOT))
        for path in sorted(DOCS.rglob("*.md"))
        if path != INDEX and path.resolve() not in linked
    ]


def main() -> int:
    files = markdown_files()
    checked, broken = check_links(files)
    unreachable = check_index()

    print(f"files={len(files)} links={checked} broken={len(broken)} unreachable={len(unreachable)}")
    for item in broken:
        print(f"BROKEN {item}")
    for item in unreachable:
        print(f"UNREACHABLE {item}")
    return 0 if not broken and not unreachable else 1


if __name__ == "__main__":
    sys.exit(main())

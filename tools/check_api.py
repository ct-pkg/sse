#!/usr/bin/env python3
"""Check the generated public header against the frozen API surface.

Rules:
  1. tools/api_surface.txt is the frozen symbol list (S0 card §3).
  2. The header generated for a real consumer must export exactly that set.
  3. Every non-Drop symbol must be mentioned by its short name in README.md.

Exit 0 when all three hold; exit 1 with a list of differences otherwise.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SURFACE = ROOT / "tools" / "api_surface.txt"
FIXTURE = ROOT / "test" / "fixtures" / "s7_integration.ct"
CT = os.environ.get("CT_BIN", str(Path.home() / ".local" / "bin" / "ct"))
SYMBOL = re.compile(r"\b(sse_[A-Za-z0-9_]+)\s*\(")


def build_header(outdir: str) -> Path:
    cmd = [
        CT, "build", str(FIXTURE), "-I", str(ROOT), "-o", "api_probe",
        "--outdir", outdir, "--cflags", f"-I {ROOT} -Wall -Wextra -Werror",
    ]
    proc = subprocess.run(cmd, cwd=outdir, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + proc.stderr)
        raise SystemExit("ct build failed")
    header = Path(outdir) / "sse.h"
    if not header.exists():
        raise SystemExit("generated header missing")
    return header


def exported(header: Path):
    return sorted(set(SYMBOL.findall(header.read_text(encoding="utf-8"))))


def read_surface():
    if not SURFACE.exists():
        return None
    return [
        line.strip()
        for line in SURFACE.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]


def short_name(symbol: str):
    if symbol == "sse_SseParser_Drop_drop":
        return None
    if symbol.startswith("sse_sse_"):
        return symbol[4:]
    return symbol.rsplit("_", 1)[-1]


def main() -> int:
    surface = read_surface()
    if surface is None:
        print("MISSING tools/api_surface.txt")
        return 1

    with tempfile.TemporaryDirectory() as tmp:
        symbols = exported(build_header(tmp))

    extra = sorted(set(symbols) - set(surface))
    missing = sorted(set(surface) - set(symbols))
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    undocumented = [s for s in surface if short_name(s) and short_name(s) not in readme]

    print(
        "header={} surface={} extra={} missing={} undocumented={}".format(
            len(symbols), len(surface), len(extra), len(missing), len(undocumented)
        )
    )
    for item in extra:
        print(f"EXTRA {item}")
    for item in missing:
        print(f"MISSING {item}")
    for item in undocumented:
        print(f"UNDOCUMENTED {item}")

    return 0 if not extra and not missing and not undocumented else 1


if __name__ == "__main__":
    sys.exit(main())

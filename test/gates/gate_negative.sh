#!/usr/bin/env bash
#
# gate_negative.sh - negative fixtures for tools/check.sh itself.
#
#   bash test/gates/gate_negative.sh
#
# A gate that never fails is not a gate. Each case builds a minimal temporary
# root, runs the real gate against it, and requires a non-zero exit.
#
# License: MIT (see LICENSE).

set -u

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    printf 'FAIL gate_negative: %s\n' "$1" >&2
    exit 1
}

run_expect_fail() {
    gate="$1"
    if CHECK_ROOT="$tmp" bash "$tmp/tools/check.sh" "$gate" >"$tmp/$gate.log" 2>&1; then
        cat "$tmp/$gate.log" >&2
        fail "$gate passed on a deliberately broken root"
    fi
}

mkdir -p "$tmp/tools" "$tmp/docs/phases/PH-99"
cp "$repo/tools/check.sh" "$tmp/tools/check.sh"
cp "$repo/docs/phases/PH-12/card.md" "$tmp/docs/phases/PH-99/card.md"
run_expect_fail g1

mkdir -p "$tmp/docs"
cp "$repo/docs/requirements.md" "$tmp/docs/requirements.md"
cp "$repo/docs/acceptance-map.md" "$tmp/docs/acceptance-map.md"
python3 - "$tmp/docs/acceptance-map.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace('ACC-A-01', 'ACC-A-99', 1)
open(p, 'w').write(s)
PY
run_expect_fail g2

printf 'ok gate_negative (g1 and g2 fail on broken roots)\n'

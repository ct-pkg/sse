#!/usr/bin/env bash
#
# tools/check.sh - package gates for ct-sse.
#
#   bash tools/check.sh g0   spec block, instantiation table, session map,
#                            version landing, package manifest
#   bash tools/check.sh g1   phase cards: required fields, version-minor,
#                            exit criteria, task columns, effort for PH-12+
#   bash tools/check.sh g2   ACC-* <-> R-* acceptance map with existing evidence
#   bash tools/check.sh g3   build + run every fixture, gate self-test
#   bash tools/check.sh g4   links, API surface, version landing, doc size
#   bash tools/check.sh g5   red evidence for behavior-changing tasks
#   bash tools/check.sh g6   issue ledger (empty ledger is valid)
#   bash tools/check.sh g7   secret scan, package manifest, ASan subset
#   bash tools/check.sh g8   clean tree, phase tag, frozen phase cards
#   bash tools/check.sh g9   spec pin (version + sha256) against the master
#
# A gate that cannot run must exit 2, never 0. Documented partial coverage is
# printed as a `note:` line so it cannot be mistaken for a passing assertion.
#
# License: MIT (see LICENSE).

set -u

here="$(cd "$(dirname "$0")" && pwd)"
root="${CHECK_ROOT:-$(cd "$here/.." && pwd)}"
pkg="$root"
SPEC_BIN="${SPEC_BIN:-/Users/samxx/trae-ws/.ai-engineering/bin/sync-agents.sh}"
SPEC="${SPEC:-/Users/samxx/trae-ws/.ai-engineering/methodology/ai-coding-workflow.md}"
CT_BIN="${CT_BIN:-$HOME/.local/bin/ct}"

gate="${1:-}"
case "$gate" in
    g0|g1|g2|g3|g4|g5|g6|g7|g8|g9) ;;
    *)
        printf 'usage: bash tools/check.sh g0|g1|g2|g3|g4|g5|g6|g7|g8|g9\n' >&2
        exit 2
        ;;
esac

fail() {
    printf 'FAIL %s: %s\n' "$gate" "$1" >&2
    exit 1
}

note() {
    printf 'note %s: %s\n' "$gate" "$1"
}

ok() {
    printf 'ok %s\n' "$gate"
    exit 0
}

# section <heading> <file>: body of a level-3 section, without the heading.
section() {
    awk -v h="$1" '
        index($0, h) == 1 { inb = 1; next }
        inb && /^### / { exit }
        inb { print }
    ' "$2"
}

pkg_version() {
    sed -n 's/^version = //p' "$pkg/ct.pkg" | head -n 1
}

main_spec_version() {
    sed -n 's/^| spec-version | `\([0-9][0-9.]*\)` |$/\1/p' "$SPEC" | head -n 1
}

block_version() {
    sed -n 's/.*spec:begin version=\([0-9][0-9.]*\).*/\1/p' "$pkg/AGENTS.md" | head -n 1
}

# --- G0 ---------------------------------------------------------------------
g0() {
    [ -x "$SPEC_BIN" ] || [ -f "$SPEC_BIN" ] || fail "sync-agents.sh not found: $SPEC_BIN"
    bash "$SPEC_BIN" --check "$pkg/AGENTS.md" >/dev/null \
        || fail "spec block / full copy check failed"

    [ -f "$pkg/docs/session-map.md" ] || fail "docs/session-map.md is missing"

    inst="$(section '### 0.1' "$pkg/AGENTS.md")"
    [ -n "$inst" ] || fail "AGENTS.md has no 0.1 instantiation section outside the block"
    rows="$(printf '%s\n' "$inst" | awk -F'|' '/^\|/ && NF >= 3 && $2 !~ /^[[:space:]]*(项|---)[[:space:]]*$/ { n++ } END { print n + 0 }')"
    [ "$rows" -eq 8 ] || fail "0.1 instantiation table must have 8 rows, got $rows"

    printf '%s\n' "$inst" | grep -qE '^\| 版本落点 \| .+ \|$' \
        || fail "0.1 版本落点 is missing or empty"

    v="$(pkg_version)"
    [ -n "$v" ] || fail "ct.pkg has no version"
    grep -q "Package version: $v" "$pkg/README.md" \
        || fail "README.md does not declare Package version: $v"
    grep -q "当前 \`$v\`" "$pkg/AGENTS.md" \
        || fail "AGENTS.md 版本落点 does not declare current $v"
    ok
}

# --- G1 ---------------------------------------------------------------------
g1() {
    shopt -s nullglob
    cards=("$pkg"/docs/phases/PH-*/card.md)
    [ "${#cards[@]}" -gt 0 ] || fail "no phase cards found"

    for card in "${cards[@]}"; do
        n="$(basename "$(dirname "$card")")"; n="${n#PH-}"; n=$((10#$n))
        grep -qE "version-minor[^0-9]*$n" "$card" \
            || fail "$card: version-minor must contain $n"
        grep -q '任务清单每项可独立验收' "$card" \
            || fail "$card: exit criteria lacks '任务清单每项可独立验收'"
        ! grep -q 'TBD' "$card" || fail "$card: contains TBD"
        for field in 目标 范围 交付物 依赖 已知风险; do
            grep -qE "^\| $field \|" "$card" || fail "$card: missing field $field"
        done
        if [ "$n" -ge 12 ]; then
            grep -q '| effort |' "$card" || fail "$card: task table lacks effort column"
            awk -F'|' '
                /^\| T[0-9]+ / {
                    e = $5; gsub(/^[ \t]+|[ \t]+$/, "", e)
                    if (e != "S" && e != "M") { print "bad effort: " $0; bad = 1 }
                }
                END { exit bad ? 1 : 0 }
            ' "$card" || fail "$card: every task needs effort S or M"
        fi
    done
    ok
}

# --- G2 ---------------------------------------------------------------------
g2() {
    [ -f "$pkg/docs/acceptance-map.md" ] || fail "docs/acceptance-map.md is missing"
    python3 - "$pkg" <<'PY' || fail "acceptance map mismatch"
import re, sys
from pathlib import Path
pkg = Path(sys.argv[1])
req = pkg / 'docs/requirements.md'
acc = pkg / 'docs/acceptance-map.md'
req_ids = sorted(set(re.findall(r'\bR-[A-F]-[0-9]{2}\b', req.read_text())))
rows = []
for line in acc.read_text().splitlines():
    if not line.startswith('| ACC-'): continue
    cols = [c.strip() for c in line.strip().strip('|').split('|')]
    if len(cols) < 5: continue
    rows.append((cols[0], cols[1], cols[4]))
acc_ids = sorted(r[0] for r in rows)
want = sorted('ACC-' + r[2:] for r in req_ids)
if acc_ids != want:
    print(f"ACC ids mismatch: missing={sorted(set(want)-set(acc_ids))} extra={sorted(set(acc_ids)-set(want))}", file=sys.stderr)
    sys.exit(1)
for a, r, ev in rows:
    if not ev:
        print(f"{a}: empty evidence", file=sys.stderr); sys.exit(1)
    paths = re.findall(r'`([^`]+)`', ev)
    if not paths:
        print(f"{a}: evidence has no path", file=sys.stderr); sys.exit(1)
    for p in paths:
        if not (pkg / p).exists():
            print(f"{a}: missing evidence {p}", file=sys.stderr); sys.exit(1)
PY
    ok
}

# --- G3 ---------------------------------------------------------------------
g3() {
    command -v "$CT_BIN" >/dev/null 2>&1 || fail "ct not found: $CT_BIN"
    tasks="s1_construct s2_basic s2_syntax s3_fields s3_retry_zero s3_state
s4_chunk s4_bom_edge s5_limits s5_abort s6_copy s6_finish_eof s7_integration
s8_registry s9_oom s9_alloc_count s9_finish_clean s9_error_codes
s10_reentrant s10_reentrant_state ex_registry ex_copy ex_error_codes"
    for t in $tasks; do
        CT_BIN="$CT_BIN" bash "$pkg/test/run.sh" "$t" >/dev/null || fail "fixture $t failed"
    done
    CT_BIN="$CT_BIN" bash "$pkg/test/gates/g12_warning.sh" >/dev/null \
        || fail "g12_warning self-test failed"
    ok
}

# --- G4 ---------------------------------------------------------------------
g4() {
    python3 "$pkg/tools/check_links.py" >/dev/null || fail "link check failed"
    python3 "$pkg/tools/check_api.py" >/dev/null || fail "API surface check failed"

    v="$(pkg_version)"
    tag="v$v"
    git -C "$pkg" cat-file -e "$tag^{commit}" 2>/dev/null || fail "tag $tag does not exist"
    git -C "$pkg" merge-base --is-ancestor "$tag^{commit}" HEAD \
        || fail "tag $tag is not an ancestor of HEAD"

    python3 - "$pkg" "$v" <<'PY' || fail "document size or version landing failed"
import sys
from pathlib import Path
pkg = Path(sys.argv[1]); v = sys.argv[2]
limits = {'README.md': 300}
exempt = {'docs/proposal.md', 'docs/phases/S0/card.md', 'docs/spec/ai-coding-workflow.md'}
bad = []
for p in sorted(list(pkg.glob('docs/**/*.md')) + [pkg/'README.md', pkg/'AGENTS.md']):
    rel = p.relative_to(pkg).as_posix()
    if rel in exempt or rel.startswith('docs/spec/'):
        continue
    text = p.read_text()
    if rel == 'AGENTS.md':
        lines = text.splitlines()
        out, inb = [], False
        for ln in lines:
            if ln.startswith('<!-- spec:begin'): inb = True; continue
            if ln.startswith('<!-- spec:end'): inb = False; continue
            if not inb: out.append(ln)
        n = len(out)
    else:
        n = len(text.splitlines())
    limit = limits.get(rel, 300)
    if n > limit:
        bad.append(f"{rel}: {n} > {limit}")
if bad:
    print('\n'.join(bad), file=sys.stderr); sys.exit(1)
if f"Package version: {v}" not in (pkg/'README.md').read_text():
    print('README version landing missing', file=sys.stderr); sys.exit(1)
PY
    note "snippet-origin enforcement is manual; docs/snippets/ does not exist yet"
    ok
}

# --- G5 ---------------------------------------------------------------------
g5() {
    CT_BIN="$CT_BIN" bash "$pkg/test/gates/g12_warning.sh" >/dev/null \
        || fail "g12_warning self-test failed"
    grep -q 'baseline:' "$pkg/docs/phases/PH-12/card.md" \
        || fail "PH-12 card has no red-evidence baseline"
    grep -q 'no-test:' "$pkg/docs/phases/PH-13/card.md" \
        || fail "PH-13 card has no no-test declaration"
    [ -f "$pkg/test/gates/g12_warning.sh" ] || fail "gate negative fixture is missing"
    bash "$pkg/test/gates/gate_negative.sh" >/dev/null \
        || fail "gate_negative self-test failed"
    note "per-gate negative coverage is limited to g12_warning and gate_negative"
    ok
}

# --- G6 ---------------------------------------------------------------------
g6() {
    [ -d "$pkg/issues" ] || fail "issues/ directory is missing"
    [ -f "$pkg/issues/README.md" ] || fail "issues/README.md is missing"
    bad=0
    for f in "$pkg"/issues/*.md; do
        [ "$(basename "$f")" = "README.md" ] && continue
        status="$(sed -n 's/^status:[[:space:]]*//p' "$f" | head -n 1)"
        case "$status" in
            open|fixed|verified|reopened|rejected|deferred|wontfix|superseded) ;;
            *) echo "bad status in $f: '$status'" >&2; bad=1 ;;
        esac
        grep -qE '^(evidence|处置):[[:space:]]*[^[:space:]]' "$f" \
            || { echo "missing evidence in $f" >&2; bad=1; }
    done
    [ "$bad" -eq 0 ] || fail "issue ledger has invalid entries"
    ok
}

# --- G7 ---------------------------------------------------------------------
g7() {
    hits="$(git -C "$pkg" ls-files -z | xargs -0 grep -InE \
        '(AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|ghp_[A-Za-z0-9]{36})' \
        2>/dev/null || true)"
    [ -z "$hits" ] || { printf '%s\n' "$hits" >&2; fail "secret scan hit"; }

    "$CT_BIN" pkg check "$pkg" >/dev/null 2>&1 || fail "ct pkg check failed"

    CT_BIN="$CT_BIN" ASAN=1 bash "$pkg/test/run.sh" s6_copy >/dev/null \
        || fail "ASan s6_copy failed"
    CT_BIN="$CT_BIN" ASAN=1 bash "$pkg/test/run.sh" s9_oom >/dev/null \
        || fail "ASan s9_oom failed"
    note "full Linux LSan evidence is recorded in docs/reviews/lsan-linux.md, not re-run here"
    ok
}

# --- G8 ---------------------------------------------------------------------
g8() {
    [ -z "$(git -C "$pkg" status --porcelain)" ] \
        || fail "working tree is not clean (commit or stash before g8)"
    v="$(pkg_version)"
    tag="v$v"
    git -C "$pkg" cat-file -e "$tag" 2>/dev/null || fail "tag $tag is missing"
    [ "$(git -C "$pkg" cat-file -t "$tag")" = "tag" ] || fail "$tag is not annotated"
    commit="$(git -C "$pkg" rev-parse "$tag^{commit}")"
    git -C "$pkg" merge-base --is-ancestor "$commit" HEAD \
        || fail "$tag does not point to an ancestor of HEAD"
    minor="${v#0.}"; minor="${minor%%.*}"
    git -C "$pkg" tag -l --format='%(contents:subject)' "$tag" | grep -q "PH-$minor" \
        || fail "$tag message lacks PH-$minor"

    for pair in "v0.12.0:PH-12" "v0.13.0:PH-13"; do
        t="${pair%%:*}"; ph="${pair##*:}"
        n="${ph#PH-}"
        git -C "$pkg" cat-file -e "$t^{commit}" 2>/dev/null || fail "missing $t"
        git -C "$pkg" diff --quiet "$t^{commit}" -- "docs/phases/PH-$n/card.md" \
            || fail "PH-$n card changed after $t (phase freeze)"
    done
    note "commit-scope and red-commit-parent checks remain manual"
    ok
}

# --- G9 ---------------------------------------------------------------------
g9() {
    bash "$SPEC_BIN" --check "$pkg/AGENTS.md" >/dev/null \
        || fail "spec block / full copy check failed"
    bv="$(block_version)"; mv="$(main_spec_version)"
    [ -n "$bv" ] && [ -n "$mv" ] || fail "cannot read spec versions"
    [ "$bv" = "$mv" ] || fail "block version $bv != master $mv"
    ok
}

"$gate"

#!/usr/bin/env bash
#
# test/run.sh - build and run one S-phase fixture.
#
#   bash test/run.sh s1_construct
#   ASAN=1 bash test/run.sh s7_copy
#
# Every fixture is built with -Wall -Wextra -Werror, run, and compared
# byte-for-byte with <task>.expected.out. A task without a wired fixture
# exits 2 instead of reporting a vacuous pass.
#
# License: MIT (see LICENSE).

set -u

task="${1:-}"
if [ -z "$task" ]; then
    echo "usage: bash test/run.sh <task-id>" >&2
    exit 2
fi
case "$task" in
i1_*)
    echo "FAIL $task: integration fixture; run bash test/integration.sh" >&2
    exit 2
    ;;
esac

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
fixtures="$repo/test/fixtures"
CT_BIN="${CT_BIN:-$HOME/.local/bin/ct}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    printf 'FAIL %s: %s\n' "$task" "$1" >&2
    exit 1
}

[ -f "$fixtures/$task.ct" ] || fail "no fixture source"
case "$task" in
    *_uaf) ;;
    *) [ -f "$fixtures/$task.expected.out" ] || fail "no expected output" ;;
esac

cflags="-I $repo -Wall -Wextra -Werror"
ldflags=""
if [ "${ASAN:-0}" = "1" ]; then
    cflags="-g -fsanitize=address -I $repo -Wall -Wextra -Werror"
    ldflags="-fsanitize=address"
fi

log="$tmp/build.log"
(
    cd "$tmp" || exit 1
    "$CT_BIN" build "$fixtures/$task.ct" -I "$repo" -o "$task" \
        --outdir "$tmp/build" --cflags "$cflags" --ldflags "$ldflags"
) >"$log" 2>&1 || { cat "$log" >&2; fail "ct build failed"; }

if [ "${task%_uaf}" != "$task" ]; then
    [ "${ASAN:-0}" = "1" ] || fail "uaf fixture requires ASAN=1"
    "$tmp/$task" >"$tmp/$task.out" 2>&1
    rc=$?
    [ "$rc" -ne 0 ] || { cat "$tmp/$task.out" >&2; fail "expected a nonzero exit"; }
    grep -q 'heap-use-after-free' "$tmp/$task.out" \
        || { cat "$tmp/$task.out" >&2; fail "expected heap-use-after-free"; }
    printf 'ok %s (asan abort as expected)\n' "$task"
    exit 0
fi

# Temporary gate: warnings are matched as text because no structured
# diagnostic path is wired yet. Replace this with a level-based check once
# the diagnostic format capability lands; do not treat the grep as permanent.
if grep -q 'warning:' "$log"; then
    cat "$log" >&2
    fail "build emitted warning"
fi

"$tmp/$task" >"$tmp/$task.out" 2>&1 \
    || { cat "$tmp/$task.out" >&2; fail "fixture failed"; }

diff -u "$fixtures/$task.expected.out" "$tmp/$task.out" \
    || fail "output mismatch"

printf 'ok %s\n' "$task"

#!/usr/bin/env bash
#
# g12_warning.sh - self-test for the PH-12 warning gate.
#
# The gate must not decide "build emitted a warning" by matching the text
# `warning:`. It must rely on the compiler's diagnostic level: `-Werror`
# turns every warning into an error, and `ct build` exits non-zero.
#
#   bash test/gates/g12_warning.sh
#
# Exit codes: 0 pass, 1 fail, 2 blocked by a missing prerequisite.
#
# License: MIT (see LICENSE).

set -u

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
CT_BIN="${CT_BIN:-$HOME/.local/bin/ct}"

fail() {
    printf 'FAIL g12_warning: %s\n' "$1" >&2
    exit 1
}

blocked() {
    printf 'BLOCKED g12_warning: %s\n' "$1" >&2
    exit 2
}

command -v "$CT_BIN" >/dev/null 2>&1 || blocked "ct not found (set CT_BIN)"

# 1. The temporary text match must be gone.
if grep -q "grep -q 'warning:'" "$repo/test/run.sh"; then
    fail "test/run.sh still matches 'warning:' text"
fi

# 2. The level mechanism must stay in place.
grep -q -- '-Werror' "$repo/test/run.sh" \
    || fail "test/run.sh lost -Werror; warnings would no longer fail the build"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 3. Inject a warning: an unused parameter must make the same build fail.
cat >"$tmp/warn.ct" <<'EOF'
int main(void)
{
    int unused = 0;
    return 0;
}
EOF

"$CT_BIN" build "$tmp/warn.ct" \
    --cflags "-Wall -Wextra -Werror" \
    -o "$tmp/warn" >"$tmp/build.log" 2>&1
rc=$?

[ "$rc" -ne 0 ] \
    || fail "a warning did not fail the build (level mechanism broken)"

printf 'ok g12_warning (level-based, exit=%s)\n' "$rc"

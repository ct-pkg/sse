#!/usr/bin/env bash
#
# integration.sh - the separate I-1 gate: real ct-http -> sse_parser.
#
# This gate is NOT part of the single-package gate (`bash test/run.sh <task>`):
# it fetches the released ct-http package with `ct get`, starts a loopback SSE
# origin, and feeds the real response chunks into the parser.
#
#   bash test/integration.sh
#
# Exit codes: 0 pass, 1 fail, 2 blocked by a missing external prerequisite.
#
# License: MIT (see LICENSE).

set -u

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
CT_BIN="${CT_BIN:-}"
if [ -z "$CT_BIN" ]; then
    if [ -x "$HOME/.local/bin/ct" ]; then
        CT_BIN="$HOME/.local/bin/ct"
    else
        CT_BIN="ct"
    fi
fi
CC_BIN="${CC:-cc}"
spec="${CT_HTTP_SPEC:-https://github.com/ct-pkg/http@0.2.1}"
task="i1_http_stream"
fixtures="$repo/test/fixtures"
server="$repo/test/integration/i1_server.py"

blocked() {
    printf 'BLOCKED %s: %s\n' "$task" "$1" >&2
    exit 2
}

fail() {
    printf 'FAIL %s: %s\n' "$task" "$1" >&2
    exit 1
}

command -v "$CT_BIN" >/dev/null 2>&1 || blocked "ct not found (set CT_BIN)"
command -v git >/dev/null 2>&1 || blocked "git is required by 'ct get'"
command -v python3 >/dev/null 2>&1 || blocked "python3 is required for the loopback origin"
command -v "$CC_BIN" >/dev/null 2>&1 || blocked "C compiler not found (set CC)"
printf '#include <curl/curl.h>\n' | "$CC_BIN" -E - >/dev/null 2>&1 \
    || blocked "libcurl headers are required (cc -lcurl build will fail)"

tmp="$(mktemp -d)"
srv_pid=""
cleanup() {
    if [ -n "$srv_pid" ]; then
        kill "$srv_pid" 2>/dev/null || true
        wait "$srv_pid" 2>/dev/null || true
    fi
    rm -rf "$tmp"
}
trap cleanup EXIT

# 1. Fetch the released package (release line, not a local checkout).
#    CT v0.63 installs into the package store and writes ct.lock; it no
#    longer creates vendor/. The lock is the handoff to `ct build --locked`.
if ! ( cd "$tmp" && "$CT_BIN" get "$spec" ) >"$tmp/get.log" 2>&1; then
    cat "$tmp/get.log" >&2
    fail "ct get '$spec' failed (needs network/git and the release tag; see log above)"
fi
[ -f "$tmp/ct.lock" ] \
    || fail "ct get did not write ct.lock (unexpected CT behaviour)"

# 2. Build from the lock. `--locked` adds the package include roots, so the
#    test does not need to know the store path or the old vendor/ layout.
#    Warnings are errors: -Werror escalates them; the exit status is the gate.
LOG="$tmp/build.log"
(
    cd "$tmp" || exit 1
    "$CT_BIN" build "$fixtures/$task.ct" \
        --locked -I "$repo" \
        -o "$task" --outdir "$tmp/build" \
        --cflags "-Wall -Wextra -Werror" --ldflags "-lcurl"
) >"$LOG" 2>&1 || { cat "$LOG" >&2; fail "ct build failed"; }

# 3. Start the loopback origin and read its port.
python3 "$server" >"$tmp/port.txt" 2>"$tmp/server.err" &
srv_pid=$!
port=""
i=0
while [ "$i" -lt 50 ]; do
    port="$(awk '/^PORT /{print $2}' "$tmp/port.txt" 2>/dev/null)"
    [ -n "$port" ] && break
    sleep 0.1
    i=$((i + 1))
done
[ -n "$port" ] || { cat "$tmp/server.err" >&2; fail "loopback origin did not report a port"; }

# 4. Run and compare.
if ! "$tmp/$task" "http://127.0.0.1:$port/sse" >"$tmp/$task.out" 2>&1; then
    cat "$tmp/$task.out" >&2
    fail "fixture exited non-zero"
fi
kill "$srv_pid" 2>/dev/null || true
wait "$srv_pid" 2>/dev/null || true
srv_pid=""
diff -u "$fixtures/$task.expected.out" "$tmp/$task.out" \
    || fail "output mismatch"

printf 'ok %s (ct-http %s, real loopback chunks)\n' "$task" "$(awk '$1 == "ct/http" {print $2}' "$tmp/ct.lock")"

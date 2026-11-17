# ct-sse

WHATWG Server-Sent Events parser for CT. Bytes in, `SseEvent`s out.

- Parses the event-stream format (HTML §9.2.6), including the stream-initial BOM.
- Does **not** do HTTP, LLM protocol semantics, reconnect policy, or routing.
- Depends only on `<stdlib.h>` / `<string.h>` / `<stdarg.h>` / `<stdio.h>`.
- Dependency direction: `ct-llm-sse → ct-sse → ct-http` (arrow = "depends on").
  ct-http must not depend on ct-sse; ct-sse must not depend on ct-llm-sse.
  The parser unit itself takes `char * + len`, so it has no compile-time HTTP
  import; the integration gate still consumes ct-http, which is the product
  direction. See [S16](docs/reviews/S16-dependency-direction.md).
- Frozen contract: [docs/phases/S0/card.md](docs/phases/S0/card.md).
  Fact check and design rulings: [docs/reviews/S0-facts.md](docs/reviews/S0-facts.md),
  [docs/reviews/S0-battle.md](docs/reviews/S0-battle.md).

Requires CT v0.53.0 or newer (verified with v0.63.0). Package version: 0.12.0.

## Layout

```
ct.pkg                 package manifest
sse/sse.h.ct           namespace sse; public types + methods + Drop
test/run.sh            build/run one fixture, diff expected output
test/fixtures/*.ct     behavior locks (s1 ... s9)
docs/                  proposal, requirements, S0 contract, reviews
```

## Use

```ct
import sse::sse;

static int on_event(SseEvent *ev, void *ud)
{
    int *n = ud;
    *n = *n + 1;
    printf("%.*s\n", ev->data_len, ev->data);
    return 0;
}

int main(void)
{
    SseParser *p = sse::sse_parser_new();
    int n = 0;
    int rc;

    p->on_event(on_event, &n);
    rc = p->feed("event: token\ndata: hello\n\n", 26);
    if (rc < 0) { /* p->error_msg() is set; stop the transport */ }
    delete p;
    return 0;
}
```

`delete p` runs `Drop` and then frees the struct with the compiler-emitted
`free`. `sse_parser_free(p)` does the same work inside the package's internal
allocation funnel; use it when allocations are counted or replaced. Never call
both on the same parser.

Build a program that imports the package:

```console
$ ct build app.ct -I . -o app --cflags "-Wall -Wextra -Werror"
```

### Registry construction

```ct
static SseRegistry base;

/* A namespaced function cannot be passed as a value (`sse::sse_parser_new`
 * is rejected: "no variable of that name in that namespace"). Wrap it. */
static SseParser *make_parser(void)
{
    return sse::sse_parser_new();
}

int main(void)
{
    SseRegistry reg = base.reg("parser", make_parser);
    SseParser *p = reg.make("parser");
    if (p == 0) { /* reg.error() == 1: no such key */ }
    delete p;
    return 0;
}
```

`reg`/`init` return the host by value, so the result lands on a variable. A
method result cannot be the receiver of the next call, so write one statement
per step (no `base.init().reg(...)`). For a local host, start with
`SseRegistry reg = base.init();`.

## Public API

Types: `SseEvent`, `SseEventCb`, `SseParser` (see the S0 card §3 for field-level
meaning). Everything else in `sse/sse.h.ct` is private.

| Symbol | Meaning |
| --- | --- |
| `SseParser *sse_parser_new(void)` | allocate a parser; `0` on OOM |
| `void sse_parser_free(SseParser *p)` | destroy inside the allocation funnel; do not mix with `delete` |
| `SseEvent *sse_event_copy(SseEvent *ev)` | deep copy of a borrow view; `0` on OOM |
| `void sse_event_free(SseEvent *ev)` | free a copy (never a view) |
| `ev->has_id()`, `ev->has_retry()`, `ev->is_message()` | field predicates |
| `p->on_event(cb, ud)` | register/clear the callback |
| `p->max_line_bytes(n)` | content-byte limit (default 65536): exactly `n` bytes pass, byte `n+1` fails; `n <= 0` is rejected |
| `p->feed(chunk, len)` | bytes in; returns events fired this call, or `-1` |
| `p->finish()` | mark EOF and discard pending bytes per WHATWG |
| `p->has_error()`, `p->error_msg()` | terminal error state / text |
| `p->error_code()` | `0` none, `1` protocol/limit, `2` OOM, `3` callback aborted, `4` reentrant call, `5` finished |
| `p->last_event_id()` | persistent last event id, `0` when cleared |
| `p->has_retry()` | 1 once a legal `retry` field was seen, `0` otherwise |
| `p->retry_hint()` | persistent retry hint; only meaningful when `has_retry()` is 1 |
| `p->reset()` | clear transient state for a new stream |
| `SseRegistry.init()` | zero the host and return it by value |
| `SseRegistry.reg(name, ctor)` | register a constructor, return the host by value |
| `SseRegistry.make(name)` | construct by key; `0` + `error()==1` when missing |
| `SseRegistry.error()` | `0` ok, `1` missing, `2` duplicate, `3` full |
| `SseRegistry.size()` | registered entries |

`ev->retry` is `-1` when the stream never sent `retry`; `retry: 0` is a real
value. `ev->id` is `0` when the last event id buffer is empty.

On the parser, check `has_retry()` before `retry_hint()`: the hint's value is
undefined until a legal `retry` field arrives. `retry: 0` counts as set
(`has_retry() == 1`, `retry_hint() == 0`) and stays set across later events
and across `reset()`.

## Contract in one page

### feed / finish / reset

- `feed` returns the number of callbacks fired **during this call**.
- Any fatal condition returns `-1`, sets `has_error()`, and enters a terminal
  state: later `feed`/`finish` answer `-1` until `reset()`.
- A callback returning non-zero aborts the feed (`error_msg()` is
  `callback aborted`, code `3`); bytes after the abort are not parsed.
- `finish()` is WHATWG EOF: pending lines and pending data are **discarded**,
  never dispatched. `feed` after `finish` answers `-1` (`parser finished`).
- `reset()` clears buffers/errors/finished and re-arms BOM handling; it keeps
  the last event id, the retry hint, the callback, and the line limit.

### Registry behavior

- `init()` zeroes the host and returns it by value.
- `reg(name, ctor)` appends; a duplicate key is **not** overwritten: `err` is
  `2`, the size is unchanged, and the first registration stays effective.
- The ninth registration sets `err=3` (`full`); the size stays 8.
- `make(name)` sets `err=0` on hit; on miss it returns `0` and sets `err=1`.
- `name` is borrowed, not copied: use a literal or static storage.
- `error()` reflects the most recent `reg`/`make`/`init`.

### Errors

| Condition | code | `error_msg()` |
| --- | --- | --- |
| line exceeds the limit | 1 | `SSE line exceeds <n> bytes` |
| allocation failure | 2 | `out of memory` |
| callback returned non-zero | 3 | `callback aborted` |
| mutating call from inside the callback | 4 | `reentrant call is not allowed` |
| `feed` after `finish` | 5 | `parser finished` |

Protocol-level oddities (unknown fields, invalid `retry`, comments, an `id`
containing NUL) are ignored and do **not** set an error.

### WHATWG rules implemented

1. CRLF, CR, and LF line endings, including CRLF split across feeds.
2. `:`-prefixed lines are comments.
3. First `:` splits field/value; one leading space is removed; no-colon lines
   have an empty value; unknown fields are ignored.
4. Each `data` appends its value plus LF; dispatch removes exactly one LF.
5. A block without any `data` field does not dispatch; `data:` fires an empty
   data event.
6. `event` defaults to `message` when absent or empty; it is cleared after
   every dispatch, including blocks without data.
7. `id` persists across events, an empty value clears it, a value containing
   NUL is ignored, and the value is captured at dispatch time.
8. `retry` accepts only non-empty ASCII digits; `0` is legal; invalid or
   overflowing values are ignored; the value persists.
9. One stream-initial `EF BB BF` is ignored, even when split across feeds.
10. EOF discards pending data (see `finish`).

### Ownership

1. `ev`, `ev->event`, `ev->data`, `ev->id` are valid until the callback returns.
2. They are also invalidated by the next `feed`/`finish`/`reset`/`delete`.
3. To keep an event beyond that, call `sse_event_copy` and `sse_event_free`.
4. A callback must not free/delete any field or the parser.
5. `ud` belongs to the caller; the parser only borrows it.
6. After `delete parser`, every uncopied view pointer is dangling.
7. `sse_event_free` accepts only the result of `sse_event_copy`.
8. Inside the event callback, do not call `feed` / `finish` / `reset` /
   `sse_parser_free` / `on_event` / `max_line_bytes` on the same parser. Such
   calls are rejected with error code `4` (`reentrant call is not allowed`);
   the parser stays usable after `reset()`. Return non-zero from the callback
   to stop early (code `3`, `callback aborted`).

### Threading

- One parser must not be `feed`/`finish`/`reset`/freed from several threads at
  once. There are no locks or atomics inside the package.
- The event callback runs synchronously on the thread that called `feed`.
- Replacing the allocator hooks is a process-wide action; do it before any
  concurrent use.

### Integration gate

The real ct-http -> parser link is a separate gate, not part of `test/run.sh`:

```console
$ bash test/integration.sh
ok i1_http_stream (ct-http 0.2.1, real loopback chunks)
```

It fetches the released ct-http with `ct get`, starts a loopback SSE origin,
and feeds the real response chunks into the parser. It needs `ct`, `git`,
`python3`, a C compiler, and libcurl headers; missing prerequisites exit 2
(blocked) instead of pretending to pass. CT v0.63 writes `ct.lock`;
`ct build --locked -I <ct-sse repo>` adds the package include roots, so the
gate no longer depends on the old `vendor/` layout. Details, exact commands,
and the interface mapping are in
[docs/reviews/S13-http-integration.md](docs/reviews/S13-http-integration.md).

### Testing limits

The fixtures do not prove leak freedom. What is and is not established:

- **Exit-reachable memory: not checked (environment gap).** macOS ASan reports
  `detect_leaks is not supported on this platform`, so LeakSanitizer is absent.
  The gap is memory still reachable at exit. A Linux CI run with
  `ASAN_OPTIONS=detect_leaks=1` (clang/gcc ASan) is required. Counter results
  below mean "no whole-buffer release is missing", never "leaks verified".
- **Real network fragmentation: not checked (environment gap).** Fixtures cover
  whole-block, byte-by-byte, and fixed-seed pseudo-random 1..7 byte chunks.
  Those break points are chosen by this repository; real TCP break points
  cannot be enumerated.
- **`ct` vs `ct-ast` equivalence: unproven, not a passing gate.** Every golden
  was produced by `ct` v0.53.0; `ct-ast` is not exercised, so the two frontends
  are not shown to agree.
- **Concurrency: unsupported by contract**, as stated in "Threading" above,
  not an untested item.
- **`finish()` cleanup**: allocator snapshots around `finish()` show no growth,
  and behavior shows discarded pending data/partial lines never reach the next
  stream. Block-internal residue lengths are not observable without an
  inspection API, which the package deliberately does not expose; that part is
  registered as unobservable, not verified.

Details and raw output: [docs/reviews/S9-allocator.md](docs/reviews/S9-allocator.md).


## CT v0.53.0-specific notes

These are language facts, not preferences (probes in `docs/reviews/S0-facts.md`):

- Static inherent methods are unusable inside a `namespace` unit, so the
  constructor is the free function `sse_parser_new()`. Two alternatives -- a
  global singleton object with an instance-method factory, and a string-keyed
  function-pointer table -- were probed and rejected (runtime lookup failure
  modes, mutable global ABI, no usability gain); see
  [docs/reviews/S0-constructor-shapes.md](docs/reviews/S0-constructor-shapes.md).
- `impl int` is rejected (`impl of an unknown trait`); `int` can only host
  methods through a `.m.ct` `map trait … for type int` static mapping, which has
  no `self` and no state. A stateful registry therefore uses a struct host; the
  probe table is in
  [docs/reviews/S8-int-host.md](docs/reviews/S8-int-host.md).
- Methods in `impl` have no forward declaration: helpers are defined before
  their callers.
- A private method whose name starts with `_` cannot be called
  (`no method '_x'`); private fields may start with `_`. This package uses no
  leading underscore on method names.
- `errdefer` is rejected in `.h.ct` units, so errors use `int` returns plus
  `error_msg()`.
- A method result cannot be the receiver of the next call: assign each step to
  a variable instead of writing `p->a()->b()`.
- `MAX_CALLS` (1024) counts direct call sites across all units of one
  `ct build`, not per unit. Splitting the package does not raise it.

## Tests

```console
$ bash test/run.sh s1_construct
$ bash test/run.sh s2_basic
$ bash test/run.sh s3_fields
$ bash test/run.sh s3_retry_zero
$ bash test/run.sh s4_chunk
$ bash test/run.sh s5_limits
$ bash test/run.sh s5_abort
$ bash test/run.sh s6_copy
$ ASAN=1 bash test/run.sh s6_copy
$ ASAN=1 bash test/run.sh s6_borrow_uaf
$ bash test/run.sh s7_integration
$ bash test/run.sh s8_registry
$ bash test/run.sh s9_oom
$ bash test/run.sh s9_alloc_count
$ bash test/run.sh s9_finish_clean
$ bash test/run.sh s10_reentrant
```

Every fixture is built with `-Wall -Wextra -Werror`; the runner fails on any
`warning:` line, on a nonzero exit, or on an output diff.

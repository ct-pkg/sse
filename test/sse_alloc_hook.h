/*
 * Test-only prototype for the package's allocator injection point.
 *
 * sse/sse.h.ct defines this function without `pub`, so it is absent from the
 * generated header and from the public API. It exists so a test harness can
 * replace the internal alloc/free pointers at runtime. Production code never
 * calls it, and it carries no failure logic of its own.
 */
#ifndef CT_SSE_ALLOC_HOOK_H
#define CT_SSE_ALLOC_HOOK_H

#include <stddef.h>

void sse_test_alloc_hook(void *(*alloc_fn)(size_t), void (*free_fn)(void *));

#endif

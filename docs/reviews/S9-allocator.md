# S9 分配器注入、OOM 与计数（门禁登记）

> 日期：2026-11-15。语言基线：ct v0.53.0（`~/.local/bin/ct`，macOS arm64）。
> 契约：[S0 card](../phases/S0/card.md) §3/§4（A-1、C-1）。夹具：`s9_oom`、`s9_alloc_count`。

## 1 注入点实测

包内所有堆分配/释放收口到两个内部函数指针（`sse_alloc_slot` / `sse_free_slot` 的静态局部），默认
`malloc` / `free`。替换入口是**非 `pub` 顶层函数** `sse_test_alloc_hook`；钩子本身不含失败逻辑，
「第 N 次失败」由测试桩的运行期变量控制。

```console
$ ct build test/fixtures/s7_integration.ct -I . -o s7 --outdir b --cflags "-Wall -Wextra -Werror"
$ nm -g s7 | grep -E 'sse_test_alloc_hook|sse_sse_parser_free'
00000001000013bc T _sse_test_alloc_hook
00000001000014c4 T _sse_sse_parser_free
$ grep -c 'alloc_hook' b/sse.h
0
```

- **不进生成头**：生成头里没有 `sse_test_alloc_hook`（grep 计数 0）；两个指针是函数内静态局部，
  根本不是符号。
- **不进公开 ABI**：`--lib` 构建中该函数被发射为 `static`，归档里没有全局符号：

```console
$ ct build sse/sse.h.ct --lib -o sse.a --outdir bl --cflags "-Wall -Wextra -Werror"
'cc' '-std=c99' '-fvisibility=hidden' '-I' 'bl' '-c' 'bl/sse.c' '-o' 'bl/sse.o'
$ nm sse.a | grep alloc_hook        # 无输出
$ grep -n 'sse_test_alloc_hook' bl/sse.c | head -2
23:static void sse_test_alloc_hook(sse_SseAllocFn, sse_SseFreeFn);
485:static void sse_test_alloc_hook(sse_SseAllocFn alloc_fn, sse_SseFreeFn free_fn) {
```

- **exe 构建**（`ct build` 默认）里它是头外内部符号，只用于同进程测试注入；不得被消费方依赖。
- **桩不进生产路径**：包内没有桩代码，也没有编译期开关；测试桩在 `test/fixtures/s9_*.ct`。
- 用法：测试用 `test/sse_alloc_hook.h` 声明原型，由 `test/run.sh` 的 `--cflags "-I <repo>"` 提供
  include 路径。CT 不发射 `extern`/裸原型的 C 声明（实测：声明被丢弃，cc 报
  `call to undeclared function`），所以必须自带 C 头。

### 1.1 顺带探到的语言边界

文件作用域的非 `pub` 全局声明会被加命名空间前缀，但函数体内对它的引用**不重写**：

```console
./hookpkg/hookpkg.h.ct:26:12: error: call to undeclared function 'g_alloc'
static hookpkg_AllocFn hookpkg_g_alloc = hp_default_alloc;   /* 声明被前缀 */
return g_alloc((size_t)(n));                                  /* 引用没被前缀 */
```

因此本包不用文件作用域全局保存指针，改用「函数内静态局部 + 取址函数」，引用与声明一致。

## 2 MAX_CALLS 实测

`MAX_CALLS` 只记「指向已解析自由函数的调用表达式」；**函数指针调用不占槽**
（[ct-lang reviews/max-calls-limit.md](../../../ct-lang/docs/reviews/max-calls-limit.md) E2/E5）。
实测方法是给入口追加 N 条 `filler(x)` 直接调用并二分（同一份探针入口）：

| 版本 | 最大 N | 占用 |
| --- | --- | --- |
| HEAD（0.8.1，无漏斗） | 999 | 25 / 1024 |
| 本次（0.9.0） | 978 | 46 / 1024 |

- 增量 +21，全部来自 `sse_mem_alloc` / `sse_mem_free` / `sse_release_buffers` 这类**直接**自由函数调用；
  `(*sse_alloc_slot())(n)` 这类间接调用不计。
- 余量 978，没有「顶到 1024」。结论：**不触发第 6 题第 4 条的停机条件**，不改回退方案。

## 3 OOM 实证

四处注入点各跑一次，`s9_oom` 原始输出：

```text
new_oom=1 live=0
feed_oom=-1 err=1 msg=out of memory live=1
recover=1 err=0 events=1 live=3
data_oom=-1 err=1 msg=out of memory
data_recover=1 err=0 events=2
copy_oom rc=1 snap_null=1 events=3
copy_ok rc=1 snap=1 data=[r]
live_after_delete=0
```

- parser 分配失败 → `sse_parser_new` 返回 0；行缓冲 / data 缓冲增长失败 → `feed` 返回 -1、
  `has_error()==1`、文本 `out of memory`；`sse_event_copy` 失败 → 返回 0，`feed` 仍成功。
- 失败后 `reset()` + 重喂可恢复，说明旧缓冲仍在 parser 手里，没有悬垂。
- `live_after_delete=0`：漏斗内的成功分配与释放全部配对。

**为什么多了 `sse_parser_free`**：`delete p` 的最终 `free(p)` 由编译器发出，绕过漏斗的 free 指针，
计数器必然差 1。`sse_parser_free` 是漏斗内的销毁出口（释放缓冲 + 释放结构）；`delete` 保留给
不注入/不计数的一般调用方。两者不得并用（卡 §4 A-1）。

## 4 计数器的界限

`g_allocs` / `g_frees` 是**测试桩**的计数器（生产二进制里没有）。三种切法都要求
`allocs == frees && live == 0`：

| 切法 | 说明 |
| --- | --- |
| 整块 | 一次 `feed(stream, len)` |
| 逐字节 | 每次 `feed(stream+i, 1)` |
| 伪随机 | 固定种子 LCG，块长 1..7（可复现，不是真随机） |

```text
whole events=2 bytes=4 len=2 allocs=5 frees=5 live=0 equal=1
byte events=2 bytes=4 len=2 allocs=5 frees=5 live=0 equal=1
random events=2 bytes=4 len=2 allocs=5 frees=5 live=0 equal=1
```

这些数字能证明的只有「整块缓冲漏释放已验证」。计数器看不见野指针、看不见越界写、也不能替代
LeakSanitizer；不得表述为「泄漏已验」。

## 5 门禁登记（四类记账）

### 5.1 退出时仍可达的内存 — **环境缺口**

- 缺的检查：进程退出时仍可达（reachable）但未释放的内存。
- 原因：macOS 上 ASan 不支持 LeakSanitizer。实测原文：
  `==70561==AddressSanitizer: detect_leaks is not supported on this platform.`
- 需要的环境：Linux CI + clang/gcc ASan，命令 `ASAN_OPTIONS=detect_leaks=1 bash test/run.sh <task>`
  （或 `LSAN_OPTIONS` 等价配置）跑全量夹具。
- 表述限制：计数器结果只能写「整块缓冲漏释放已验证」。

### 5.2 真实网络分片 — **环境缺口**

- 当前跨 chunk 用例的切点由本仓库选定：整块、逐字节、固定种子伪随机 1..7 字节。
- 真实 TCP 断点无法穷举；本仓库无法给出「已覆盖真实网络分片」的结论。

### 5.3 `ct` 与 `ct-ast` 的等价性 — **登记项，不计入门禁通过数**

- 所有 golden 由 `ct` v0.53.0 跑出；`ct-ast` 未参与，两者等价性**未证**。
- 因此「全量夹具通过」只说明 `ct` 前端下的行为；不得把该数量计为含 `ct-ast` 的门禁通过数。

### 5.4 并发 — **契约（不是未测）**

- 同一个 parser 不得被多线程同时 `feed` / `finish` / `reset` / `sse_parser_free`。
- 回调在调用 `feed` 的线程上同步触发。
- 包内无锁、无原子操作；替换 alloc/free 指针是进程级操作，必须在并发使用前完成。
- 契约落在 [S0 card](../phases/S0/card.md) §4 C-1 与 README「Threading」。

## 6 `finish()` 清理的可观测性（第 12 题裁定）

**不加只读视察接口。** 生成头不增加任何查询/调试方法，测试也不断言内部字段。只用两类证据：

1. **分配计数快照**（`s9_finish_clean`）：`finish()` 前后 `live blocks` / `live bytes` 的增量都是 0；
   `sse_parser_free` 之后两者归零。
2. **行为断言**：`finish()` 后 `feed` 返回 -1、`error_msg()` 为 `parser finished`、回调次数不变；
   `reset()` 后重喂只看到新内容——残留 data 不会拼进新事件，残留半行（`retry: 7` / `id: 9` /
   `event: stale` 无结尾换行）不会生效。

原始输出：

```text
pending rc=0 n=0
finish=0 n=0 add_blocks=0 add_bytes=0
blocked rc=-1 err=1 msg=parser finished n=0
e1 data=[fresh] len=5 msg=1 id=- has_retry=0
fresh rc=1 n=1
partial_retry_has=0
partial_id_null=1
e2 data=[z] len=1 msg=1 id=- has_retry=0
after_stale rc=1 n=2
live blocks=0 bytes=0
```

**不可观测（如实登记）**：`line_len` / `data_len` / `event_len` 这类**块内残留长度**无法由计数器
看到（计数器只知道分配块大小，不知道块内已写入多少），也无法在不加只读接口的前提下断言。
按第 12 题裁定不加接口，因此「残留缓冲字节数归零」不能作为直接的字节断言，只能由上面的行为
断言覆盖。不得用内部字段绕过，也不得把它写成「已在字节级验证」。


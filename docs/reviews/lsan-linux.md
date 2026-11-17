# PH-13：Linux LSan 运行记录

> 日期：2026-11-17。主机 macOS arm64；容器 Ubuntu 24.04（aarch64），GCC 13.3.0；
> Linux 侧 CT **v0.61.1**（从本地 `ct-lang` 源码 `086d37e` 构建；主机 CT 为 v0.63.0）。
> 目的：回答“退出时仍可达内存”是否有 LSan 证据，而不是用分配计数器冒充。

## 1 环境与构建

容器镜像 `localhost/ct-ci:24.04` 预装 `cc`、`git`、`tar`、`make`、libasan、libcurl；
镜像内没有 CT 二进制，按 `ct-lang/install.sh` 从本地源码构建，产物放在 podman volume
`ct-bin`：

```console
$ podman volume create ct-bin
$ podman run --rm -v ct-bin:/out -v /Users/samxx/trae-ws/ct-lang:/src:ro \
    localhost/ct-ci:24.04 bash -lc '
      cp -a /src /tmp/ctsrc && cd /tmp/ctsrc &&
      CT_SOURCE_DIR=. CT_PREFIX=/out ./install.sh'
==> building L0 (the C seed)
==> building L1
==> building L2 (the regression oracle)
==> building ct-ast (the installed entry)
==> installed /out/ct (ct v0.61.1) and /out/ctc
```

## 2 全量 ASan + LSan

`ASAN=1` 让 `test/run.sh` 用 `-g -fsanitize=address` 构建；Linux 的 GCC ASan 内含 LSan，
`ASAN_OPTIONS=detect_leaks=1` 在进程退出时检查仍可达内存。

```console
$ podman run --rm -v ct-bin:/out -v /Users/samxx/trae-ws/ct-sse:/workspace:ro \
    -w /workspace -e CT_BIN=/out/ct -e ASAN_OPTIONS=detect_leaks=1 \
    localhost/ct-ci:24.04 bash -lc '
      set -e
      for t in s1_construct s2_basic s2_syntax s3_fields s3_retry_zero s3_state \
        s4_chunk s4_bom_edge s5_limits s5_abort s6_copy s6_finish_eof s7_integration \
        s8_registry s9_oom s9_alloc_count s9_finish_clean s9_error_codes \
        s10_reentrant s10_reentrant_state ex_registry ex_copy ex_error_codes; do
        ASAN=1 bash test/run.sh "$t"
      done'
ok s1_construct
ok s2_basic
ok s2_syntax
ok s3_fields
ok s3_retry_zero
ok s3_state
ok s4_chunk
ok s4_bom_edge
ok s5_limits
ok s5_abort
ok s6_copy
ok s6_finish_eof
ok s7_integration
ok s8_registry
ok s9_oom
ok s9_alloc_count
ok s9_finish_clean
ok s9_error_codes
ok s10_reentrant
ok s10_reentrant_state
ok ex_registry
ok ex_copy
ok ex_error_codes
exit=0
$ grep -c LeakSanitizer /tmp/lsan-linux.log
0
```

## 3 负例：LSan 确实在运行

“没有报告”必须能区分“没泄漏”和“LSan 没跑”。故意泄漏 16 字节：

```console
$ cat /tmp/leak.c
#include <stdlib.h>
int main(void) { char *p = malloc(16); p[0] = 0; return 0; }
$ cc -g -fsanitize=address /tmp/leak.c -o /tmp/leak
$ ASAN_OPTIONS=detect_leaks=1 /tmp/leak
=================================================================
==10==ERROR: LeakSanitizer: detected memory leaks

Direct leak of 16 byte(s) in 1 object(s) allocated from:
    #0 ... in malloc
    #1 ... in main /tmp/leak.c:2
...
SUMMARY: AddressSanitizer: 16 byte(s) leaked in 1 allocation(s).
$ echo $?
1
```

负例退出 1 且出现 `LeakSanitizer`，证明同一环境下的 LSan 是可触发的；第 2 节 23 条夹具
全绿且 0 条 `LeakSanitizer`，才可写成“这批夹具的退出可达内存已由 LSan 检查”。

## 4 macOS 回归（E-2）

macOS 的 ASan **不支持** `detect_leaks`。强制加该变量会直接失败：

```console
$ ASAN=1 ASAN_OPTIONS=detect_leaks=1 bash test/run.sh s1_construct
==...==AddressSanitizer: detect_leaks is not supported on this platform.
Abort trap: 6
FAIL s1_construct: fixture failed
exit=1
```

因此 E-2 的“同一命令”按**同一批夹具、macOS 的 ASan 配置**执行，不把 Linux 专属的
`detect_leaks=1` 强加到 macOS。结果：

```console
$ for t in ...; do ASAN=1 bash test/run.sh "$t"; done
ok s1_construct
...
ok ex_error_codes
MACOS_ASAN_GREEN
exit=0
```

这不是放宽泄漏判据：macOS 不做 LSan 结论，泄漏结论只在第 2 节的 Linux 环境成立。

## 5 结论与边界

| 结论 | 证据 | 能说明什么 |
| --- | --- | --- |
| Linux 全量夹具在 ASan+LSan 下退出 0 | §2 的 23 条 `ok`、`LeakSanitizer` 计数 0 | 这批夹具的退出可达堆内存未检出泄漏 |
| LSan 在该环境可触发 | §3 负例退出 1、原文 `LeakSanitizer: detected memory leaks` | 第 2 节的 0 报告不是“LSan 没跑” |
| macOS ASan 不回归 | §4 的 23 条 `ok` | 新增 Linux 记录没有改变 macOS 门禁 |
| 分配计数器 | `s9_alloc_count` 的 `allocs==frees && live==0` | 只证明整块缓冲没有漏释放，**不等于** LSan |
| 真实 TCP 分片 | 未覆盖 | 环境缺口，切点由夹具选定 |
| `ct` / `ct-ast` 等价性 | 未证 | 不把数量计入门禁通过 |

## 6 复现入口

```console
$ bash test/run.sh s1_construct          # 单条
$ ASAN=1 bash test/run.sh s6_copy         # 单条 ASan
$ bash test/integration.sh                # 独立集成门禁
```

Linux 全量命令见 §2；需要先按 §1 构建 Linux CT。

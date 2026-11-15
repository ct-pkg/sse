# S0–S7 收口报告

> 日期：2026-11-15。包版本：0.7.0。语言基线：ct v0.53.0。
> 契约：[S0 card](../phases/S0/card.md)。事实：[S0-facts](S0-facts.md)。裁定：[S0-battle](S0-battle.md)。

## 1 交付物

| 相 | 交付 | 提交主题 |
| --- | --- | --- |
| S0 | 契约卡、事实报告、battle 报告 | `docs: 冻结 S0 契约并落事实核对与 battle` |
| S1 | `sse/sse.h.ct` 骨架、`test/run.sh`、`s1_construct` | `feat(sse): S1 骨架与构造` |
| S2 | 行切分/字段/data 分发、`s2_basic` | `feat(sse): S2 最小解析闭环` |
| S3 | event/id/retry、`s3_fields` | `feat(sse): S3 字段语义` |
| S4 | 分片/BOM、`s4_chunk` | `feat(sse): S4 分片与 BOM` |
| S5 | 限额/终止态、`s5_limits`、`s5_abort` | `feat(sse): S5 限额与终止态` |
| S6 | copy/free、`s6_copy`、`s6_finish_eof`、`s6_borrow_uaf` | `feat(sse): S6 拷贝出口` |
| S7 | `README.md`、`s7_integration` | `test(sse): S7 示例与文档` |

## 2 门禁原始结果

```console
$ bash test/run.sh s1_construct
ok s1_construct
$ bash test/run.sh s2_basic
ok s2_basic
$ bash test/run.sh s3_fields
ok s3_fields
$ bash test/run.sh s4_chunk
ok s4_chunk
$ bash test/run.sh s5_limits
ok s5_limits
$ bash test/run.sh s5_abort
ok s5_abort
$ bash test/run.sh s6_copy
ok s6_copy
$ bash test/run.sh s6_finish_eof
ok s6_finish_eof
$ bash test/run.sh s7_integration
ok s7_integration
$ ASAN=1 bash test/run.sh s6_copy
ok s6_copy
$ ASAN=1 bash test/run.sh s6_borrow_uaf
ok s6_borrow_uaf (asan abort as expected)
```

`test/run.sh` 对每次构建做三件事：`-Wall -Wextra -Werror` 构建、拒绝任何 `warning:` 行、逐字节 diff 期望输出。

## 3 退出判据逐条

### E-1 WHATWG W1–W10

| 规则 | 用例 | 断言 |
| --- | --- | --- |
| W1 | `s4_chunk` | `data: a\r` + `\n\r\n` 跨分片出一条；`data: b\r\r` 出 b |
| W2 | `s7_integration` | `: keepalive` 被忽略，随后仍出 `world` |
| W3 | `s2_basic` / `s3_fields` / `s5_limits` | 第一个冒号、只去一个空格、`event:` 空值、未知字段 `12345678` 不分发 |
| W4 | `s2_basic` | 三条 `data:` → `data_len==10`，只去一个末尾 LF |
| W5 | `s2_basic` | `data:\n\n` → `len=0` 事件仍分发 |
| W6 | `s3_fields` | 缺省/空 `event` → `message`；`event: ghost` 无 data 块后清空 |
| W7 | `s3_fields` | id 持久、空值清除、含 NUL 忽略、dispatch 时刻取值 |
| W8 | `s3_fields` | 3000 / 0 生效；`+5`、`-1`、`3x`、空值忽略并保留前值 |
| W9 | `s4_chunk` | BOM 整块与跨分片均被吞掉；非 BOM 首字节回放 |
| W10 | `s6_finish_eof` | `data: pending` + `finish` → 0 事件 |

### E-2 F-1–F-3

| 契约 | 用例 |
| --- | --- |
| F-1 计数/终止/中断 | `s1_construct`、`s4_chunk`（`feed(0,0)=0`）、`s5_limits`、`s5_abort`、`s6_finish_eof` |
| F-2 EOF 丢弃 | `s6_finish_eof` |
| F-3 reset | `s4_chunk`（重武装 BOM）、`s5_limits`（保留上限）、`s5_abort`、`s3_fields`（保留 id/retry） |

### E-3 错误文本

`SSE line exceeds 8 bytes`、`callback aborted`、`parser finished` 均按 X-1 精确比对。
`out of memory` 分支无法在不注入分配失败的前提下触发，**未实测**（见 §4）。

### E-4 导出符号

生成头（`ct build s7_integration.ct -I . --outdir ...`）导出的全部符号：

```text
sse_SseParser_Drop_drop
sse_sse_parser_new
sse_sse_parser_free
sse_sse_event_copy
sse_sse_event_free
sse_SseEvent_has_id / has_retry / is_message
sse_SseParser_on_event / max_line_bytes / feed / finish
sse_SseParser_has_error / error_msg / error_code / last_event_id / has_retry / retry_hint / reset
```

与卡 §3 清单一一对应；无私有 helper 泄漏。

### E-5 内存

- `ASAN=1 bash test/run.sh s6_copy`：深拷贝在 `delete parser` 后仍可读，进程正常退出。
- `ASAN=1 bash test/run.sh s6_borrow_uaf`：`delete` 后读 borrow 视图，ASan 报 `heap-use-after-free`，进程 abort。
- 泄漏检测：macOS 的 ASan 默认不带 LeakSanitizer，**未做泄漏量化**；只验证了无崩溃/无 UAF。
  该环境缺口、真实网络分片缺口、`ct`/`ct-ast` 等价性登记与并发契约统一记在
  [S9-allocator](S9-allocator.md) §5；`ct`/`ct-ast` 等价性**不计入**门禁通过数。

### E-6 零警告

`test/run.sh` 在每次构建后检查 `warning:`，9 个非 UAF 夹具全部通过；UAF 夹具同样先过构建检查。

### E-7 禁用形态

```console
$ grep -n "static.*new\|::new" sse/sse.h.ct
（无输出）
$ grep -n "errdefer" sse/sse.h.ct
（无输出）
$ grep -n -- ")->" sse/sse.h.ct test/fixtures/*.ct
（无输出）
```

私有 helper 无前导下划线；helper 均在调用者之前定义。

### E-8 每项可独立验收

卡 §5 的 7 条 `verify` 命令全部单跑通过（见 §2）。每相均有独立夹具，回滚任一相只删除对应夹具与该相实现块即可。

### E-9 README

`README.md` 含公开 API 表、F-1–F-3、W1–W10、M-1 七条所有权规则、X-1 四类错误文本、ct v0.53.0 五个绕法、`MAX_CALLS` 说明与测试命令。

## 4 偏差与未覆盖项（不计通过）

| # | 项 | 处理 |
| --- | --- | --- |
| D-1 | S6 原计划（reset/finish/查询）无独立红证：行为已在 S1/S4/S5 落地 | S6/S7 重切，copy 移到 S6，README/示例移到 S7；记入卡 §8 |
| D-2 | `out of memory` 分支未实测 | 已由 S9 的注入桩实测（`s9_oom`）；不再列为未覆盖 |
| D-3 | 泄漏未量化 | macOS ASan 无 LSan；S9 计数器只证明「整块缓冲漏释放已验证」，退出可达内存仍为环境缺口（[S9-allocator](S9-allocator.md) §5.1） |
| D-4 | `finish()` 清理残留缓冲不可观测 | 第 12 题裁定后拆成两类证据：计数快照（`finish` 前后不增、销毁后归零）+ 行为断言（不吐旧数据、半行不生效），见 `s9_finish_clean`；块内残留长度仍不可观测，不加只读接口（[S9-allocator](S9-allocator.md) §6） |
| D-5 | `SseParser` 字段布局随生成头公开 | CT 的 `.h.ct` 必然导出结构体布局；契约已声明「布局不承诺」 |
| D-6 | 构建输出 `warning:` 依赖 ct/cc 文本 | **临时做法**：只对构建日志做 `warning:` 文本匹配；待结构化诊断格式能力落地后替换为按诊断级别判断，不得视为永久方案 |

## 5 结论

S0–S7 按冻结契约交付，9 个常规夹具 + 1 个 ASan UAF 负例全绿；E-1、E-2、E-3（除 OOM）、E-4、E-6、E-7、E-8、E-9 成立，E-5 部分成立（UAF 已验证，泄漏未量化），D-2/D-3 不记通过。包版本 0.7.0，仅本地提交，未 push、未打 tag。

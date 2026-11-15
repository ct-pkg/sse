# S0 契约卡（冻结）

> 项目：ct-sse（WHATWG SSE 解析包）。规范版本：1.10.0。冻结时间：2026-11-15。
> 依据：[S0 事实核对](../reviews/S0-facts.md)、[S0 battle](../reviews/S0-battle.md)。
> 冻结规则：本卡 §2–§4 自 S1 首个实现提交起不得修改；确需变更时关闭当前相、新开一相。
> 版本映射：`S<n>` 收口 → `0.<n>.0`；S0 只冻结契约，不移动版本。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 编号 | `S0`（后续 `S1`…`S7`） |
| 目标 | 用一份可核对的契约固定 SSE 解析器的 API、返回值、所有权与 WHATWG 语义，使 S1–S7 各相可独立验收 |
| 范围 | 做什么：冻结 §2–§4；不做什么：不写实现、不建门禁脚本、不改 ct-lang |
| 交付物 | 本卡、`docs/reviews/S0-facts.md`、`docs/reviews/S0-battle.md`、`docs/session-map.md` 更新 |
| 依赖 | ct v0.53.0（`~/.local/bin/ct`）；无外部网络依赖 |
| 规范版本 | 1.10.0（`docs/spec/ai-coding-workflow.md`） |
| version-minor | S0 不移动；S1–S7 分别为 1–7 |
| 已知风险 | ①namespace 单元无静态固有方法（已绕行）；②html §9.2.6 的 EOF 语义与提案相反；③链式调用不可用；④`MAX_CALLS` 按整次构建累计 |

## 2 包形态与语言绕法（冻结）

| 项 | 冻结口径 |
| --- | --- |
| 单元 | `sse/sse.h.ct`，首行 `namespace sse;`；消费方 `import sse::sse;` |
| 构造 | `pub SseParser *sse_parser_new(void)` 自由函数；**不用**静态固有方法（v0.53.0 带 namespace 不可用） |
| 销毁 | 调用方 `delete p;`；`new` 返回裸指针，不写 `own` |
| 私有 helper | `impl SseParser` 内不带 `pub` 的方法；**必须定义在调用者之前**；**方法名不得以 `_` 开头**（字段 `_x` 可以） |
| 错误格式化 | `.h.ct` 内文件作用域 `static int sse_set_error(SseParser *p, char *fmt, ...)`；**不用 errdefer**（`.h.ct` 禁止） |
| 链式 | 方法可返回 `self`，但调用结果不能作为下一跳接收者；示例必须逐句落变量 |
| 内存 | 缓冲全用 `char *` + `realloc` 手动容量；不用 `Vec`；`Vec` 无借用出口，不请求语言改动 |

## 3 公开 API 面（冻结，符号级）

类型：

```ct
pub struct SseEvent {
    char *event;    /* 非 NULL；缺省为 "message" */
    char *data;     /* 非 NULL；data_len 之后补 NUL，但可含内嵌 NUL */
    int   data_len;
    char *id;       /* NULL 表示本流尚无 lastEventId */
    int   retry;    /* -1 表示本流从未设置 retry；否则为快照值 */
}

pub typedef int (*SseEventCb)(SseEvent *ev, void *ud);

pub struct SseParser { /* 字段私有，不对调用方承诺布局 */ } use Drop;
```

函数与方法（清单外一律私有）：

| 符号 | 契约 |
| --- | --- |
| `SseParser *sse_parser_new(void)` | `calloc` 成功返回实例；失败返回 0 |
| `SseEvent *sse_event_copy(SseEvent *ev)` | 深拷贝；OOM 返回 0；只接受 borrow 视图 |
| `void sse_event_free(SseEvent *ev)` | 只释放 copy 的结果（字段 + 结构） |
| `SseEvent.has_id()` | `id != NULL` |
| `SseEvent.has_retry()` | `retry >= 0` |
| `SseEvent.is_message()` | `strcmp(event, "message") == 0` |
| `int SseParser.on_event(SseEventCb cb, void *ud)` | 注册/清除回调；总返回 0 |
| `int SseParser.max_line_bytes(int n)` | `n >= 1` 设置上限并返回 0；`n <= 0` 返回 -1 且保留旧值 |
| `int SseParser.feed(char *chunk, int len)` | 见 §4 F-1 |
| `int SseParser.finish()` | 见 §4 F-2 |
| `int SseParser.has_error()` | 0/1 |
| `char *SseParser.error_msg()` | 无错误返回 0；有错误返回稳定文本 |
| `char *SseParser.last_event_id()` | 无则 0，否则返回内部持久缓冲（生命周期同 parser） |
| `int SseParser.retry_hint()` | 未设置返回 -1 |
| `void SseParser.reset()` | 见 §4 F-3 |

## 4 行为契约（冻结）

### F-1 `feed(chunk, len)`

1. `chunk == 0 || len <= 0` → 返回 0，不改变状态。
2. 成功 → 返回**本次调用**触发的事件回调次数（`>= 0`）。
3. 致命（行超限 / OOM / 回调中断 / 已 `finish` / 已处于错误态）→ 返回 `-1`，`has_error()==1`，进入终止态。
4. 终止态下再次 `feed`/`finish` 立即返回 `-1`，不再解析；唯一出口是 `reset()`。
5. 回调返回非 0 → 中断：本块剩余字节不再解析，`error_msg()` 为 `callback aborted`。
6. 事件计数只统计**本次**调用内成功分发的事件；中断前已分发的事件照常计数（但整体返回 -1）。

### F-2 `finish()`

1. WHATWG W10：EOF 时**丢弃**残留半行与未分发的 data，**不分发**流末不完整事件。
2. 正常返回 0；已处于错误态或已 finish → 返回 -1。
3. finish 后 `feed` 返回 -1（`parser finished`），直到 `reset()`。
4. 不隐式 reset、不隐式 delete；id/retry 保留。

### F-3 `reset()`

清空：行/data/event 缓冲、`has_data`、`saw_cr`、BOM 状态、错误文本、错误标志、finish 标志。
保留：lastEventId 及有效性、retry 及有效性、回调注册、`max_line_bytes`。
返回 void。

### W-1 WHATWG 十条（唯一合规清单）

| # | 冻结口径 |
| --- | --- |
| W1 | CRLF / CR / LF 三种行结束；CRLF 可跨 `feed` 分片 |
| W2 | 行首 `:` 整行忽略 |
| W3 | 第一个 `:` 切分；值前只去一个空格；无冒号＝空值；未知字段忽略；字段名大小写敏感 |
| W4 | `data` 追加「值 + LF」；dispatch 只去一个末尾 LF |
| W5 | 以「本块是否出现过 `data` 字段」判定；`data:` 分发空 data 事件 |
| W6 | `event` 缺省/空值＝`message`；dispatch 后清空，无 data 的块也清空 |
| W7 | `id` 持久；空值清除；值含 NUL 整条忽略；dispatch 时刻取值 |
| W8 | `retry` 仅非空纯 ASCII 数字；`retry: 0` 合法；溢出/非法忽略；跨事件持久 |
| W9 | 流首（含 `reset` 后）一个 `EF BB BF` 忽略；非 BOM 前缀按普通字节回放 |
| W10 | EOF 丢弃 pending data（见 F-2） |

### M-1 所有权契约（写入 README，逐条可核对）

1. `ev` 及 `ev->event/data/id` 只在回调返回前有效。
2. 有效期还在下一次 `feed`/`finish`/`reset`/`delete` 时提前结束。
3. 跨回调保留必须 `sse_event_copy`，并用 `sse_event_free` 释放。
4. 回调不得 `free`/`delete` 任何字段。
5. `ud` 归注册方所有，回调只借不还。
6. `delete parser` 后，任何未 copy 的视图指针均悬垂。
7. `sse_event_free` 只接受 `sse_event_copy` 的返回值。

### X-1 错误文本（精确比对）

| 场景 | `has_error()` | `error_msg()` |
| --- | --- | --- |
| 行超限 | 1 | `SSE line exceeds <n> bytes`（`<n>` 为当前上限十进制） |
| 分配失败 | 1 | `out of memory` |
| 回调中断 | 1 | `callback aborted` |
| `finish` 后继续 feed | 1 | `parser finished` |
| 正常 | 0 | NULL |

协议层非致命（未知字段、非法 retry、注释、NUL id）**不置错**。

## 5 任务清单（冻结）

| id | 交付物 | 验收命令 | 提交 | effort | 可单独回滚 |
| --- | --- | --- | --- | --- | --- |
| S1 | `sse/sse.h.ct` 骨架 + `test/run.sh` + `test/fixtures/s1_*.ct` | `bash test/run.sh s1_construct` | `feat(sse): S1 骨架与构造` | S | 是 |
| S2 | 行切分/字段解析/data 分发 + `s2_*` 夹具 | `bash test/run.sh s2_basic` | `feat(sse): S2 最小解析闭环` | M | 是 |
| S3 | event/id/retry 语义 + `s3_*` 夹具 | `bash test/run.sh s3_fields` | `feat(sse): S3 字段语义` | M | 是 |
| S4 | 跨分片行结束 + BOM + `s4_*` 夹具 | `bash test/run.sh s4_chunk` | `feat(sse): S4 分片与 BOM` | M | 是 |
| S5 | 行上限/终止态 + `s5_*` 夹具 | `bash test/run.sh s5_limits` | `feat(sse): S5 限额与终止态` | M | 是 |
| S6 | `sse_event_copy`/`sse_event_free` + `s6_copy` 夹具 | `bash test/run.sh s6_copy` | `feat(sse): S6 拷贝出口` | M | 是 |
| S7 | README + 集成样例 + `s7_integration` 夹具 | `bash test/run.sh s7_integration` | `test(sse): S7 示例与文档` | S | 是 |

每项任务的 `test` 提交先行、实现提交紧随（T-7）；红证写入提交正文 `red: rc=<N>, "<失败文案>"`。

## 6 退出判据（冻结）

| # | 判据 | 核对方式 |
| --- | --- | --- |
| E-1 | WHATWG W1–W10 每条至少一个用例，且用例写明回调次数/字段值/`has_error` | `bash test/run.sh <task>` 逐条输出 |
| E-2 | `feed`/`finish`/`reset` 的 F-1–F-3 契约逐条有正例或负例 | 同上 |
| E-3 | 错误文本按 X-1 精确比对 | `bash test/run.sh s5_limits` |
| E-4 | 生成头导出的符号与本卡 §3 清单完全一致（不多不少） | `nm`/`grep` 比对生成 `.h` |
| E-5 | 借用负例在 ASan 下报 heap-use-after-free；copy 正例无泄漏 | `ASAN=1 bash test/run.sh s6_borrow_uaf`；`ASAN=1 bash test/run.sh s6_copy` |
| E-6 | 构建零警告（`-Wall -Wextra -Werror`，且 ct 自身无 warning） | `test/run.sh` 对 stderr 检查 |
| E-7 | 不依赖静态固有方法 / errdefer / 链式调用（可 grep 核对） | `grep -n` 本卡 §2 三个禁用形态 |
| E-8 | 任务清单每项可独立验收（6.6 T-6） | 逐项跑各自 `verify` |
| E-9 | README 含 M-1 七条所有权契约与 §3 公开 API 清单 | 人工逐条核对 |

## 7 非目标

HTTP 传输、LLM 协议语义、重连策略、事件路由/多订阅、字符编码转换（BOM 除外）、线程安全、借用检查、方法级私有之外的可见性扩展、`Vec.data()` 语言请求。

## 8 变更记录

| 日期 | 变更 | 依据 |
| --- | --- | --- |
| 2026-11-15 | 首版冻结；相对提案修正 WHATWG W10、retry 0 值、静态工厂、行上限、分期 | S0-facts、S0-battle |
| 2026-11-15 | S6/S7 重切：原 S6（reset/finish）的行为已在 S1/S4/S5 落地，无独立红证可出；copy/free 移到 S6，README/集成样例移到 S7 | T-7 红证要求；E-5 需 copy 夹具 |

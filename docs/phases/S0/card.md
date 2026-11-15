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

pub typedef SseParser *(*SseCtor)(void);

pub struct SseRegistry { /* count/err/names[8]/fns[8]，布局不承诺 */ };
```

函数与方法（清单外一律私有）：

| 符号 | 契约 |
| --- | --- |
| `SseParser *sse_parser_new(void)` | `calloc` 成功返回实例；失败返回 0 |
| `void sse_parser_free(SseParser *p)` | 走内部分配漏斗的销毁出口：释放缓冲并释放结构；不得与 `delete` 并用 |
| `SseEvent *sse_event_copy(SseEvent *ev)` | 深拷贝；OOM 返回 0；只接受 borrow 视图 |
| `void sse_event_free(SseEvent *ev)` | 只释放 copy 的结果（字段 + 结构） |
| `SseEvent.has_id()` | `id != NULL` |
| `SseEvent.has_retry()` | `retry >= 0` |
| `SseEvent.is_message()` | `strcmp(event, "message") == 0` |
| `int SseParser.on_event(SseEventCb cb, void *ud)` | 注册/清除回调；总返回 0 |
| `int SseParser.max_line_bytes(int n)` | `n >= 1` 设置上限并返回 0；`n <= 0` 返回 -1 且保留旧值；`n` 是内容字节上限（不含 NUL），恰好 `n` 字节的行合法，第 `n+1` 字节报超限 |
| `int SseParser.feed(char *chunk, int len)` | 见 §4 F-1 |
| `int SseParser.finish()` | 见 §4 F-2 |
| `int SseParser.has_error()` | 0/1 |
| `char *SseParser.error_msg()` | 无错误返回 0；有错误返回稳定文本 |
| `int SseParser.error_code()` | 0 无错误、1 协议/上限、2 OOM、3 回调中止、4 重入、5 已 finish |
| `char *SseParser.last_event_id()` | 无则 0，否则返回内部持久缓冲（生命周期同 parser） |
| `int SseParser.has_retry()` | 本流是否已收到合法 `retry` 字段；0/1 |
| `int SseParser.retry_hint()` | 仅当 `has_retry() == 1` 时有意义；未设置时返回值不构成契约 |
| `void SseParser.reset()` | 见 §4 F-3 |
| `SseRegistry SseRegistry.init()` | 归零宿主并按值返回；局部未初始化变量可先 `init` |
| `SseRegistry SseRegistry.reg(char *name, SseCtor fn)` | 注册并返回宿主；见 §4 R-1 |
| `SseParser *SseRegistry.make(char *name)` | 查表构造；缺失返回 0 并置 err |
| `int SseRegistry.error()` | 0 成功、1 缺失、2 重键、3 满 |
| `int SseRegistry.size()` | 当前条目数 |

清单外：`sse_test_alloc_hook` 是测试注入点，**不是**公开 API，不进生成头；`--lib` 构建中它为 `static`。

## 4 行为契约（冻结）

### F-1 `feed(chunk, len)`

1. `chunk == 0 || len <= 0` → 返回 0，不改变状态。
2. 成功 → 返回**本次调用**触发的事件回调次数（`>= 0`）。
3. 致命（行超限 / OOM / 回调中断 / 已 `finish` / 已处于错误态）→ 返回 `-1`，`has_error()==1`，进入终止态。
4. 终止态下再次 `feed`/`finish` 立即返回 `-1`，不再解析；唯一出口是 `reset()`。
5. 回调返回非 0 → 中断：本块剩余字节不再解析，`error_msg()` 为 `callback aborted`（码 3）。
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

### A-1 分配与销毁（第 6/7 题裁定）

1. 所有堆分配与释放经两个内部函数指针（默认 `malloc` / `free`）；测试可用 `sse_test_alloc_hook` 在运行期替换。
2. 两个指针与钩子**不进生成头**；exe 构建中钩子是头外内部符号，`--lib` 构建中为 `static`，均不构成公开 ABI。
3. 失败注入次数由测试桩的运行期变量控制；包内没有桩、没有编译期开关。
4. `sse_parser_free` 是漏斗内的销毁出口；`delete` 的最终 `free` 由编译器发出，绕过漏斗计数。二者不得并用。

### C-1 并发边界（第 8 题裁定，契约而非未测）

1. 同一个 parser 不得被多线程同时 `feed` / `finish` / `reset` / `sse_parser_free`。
2. 回调在调用 `feed` 的线程上**同步**触发；包内无锁、无原子操作。
3. 替换 alloc/free 指针是进程级操作，必须在并发使用前完成。

### C-2 回调内禁止重入（第 15 题裁定）

1. 进入事件回调前置 `in_callback`，回调返回后清位；该检查在**生产构建**中同样生效，成本是一个布尔判断。
2. 回调执行期间，不得对同一 parser 调用 `feed` / `finish` / `reset` / `sse_parser_free` / `on_event` / `max_line_bytes`：
   - 返回 `int` 的方法返回 -1 并置错误；`reset` 与 `sse_parser_free` 只置错误、不执行动作。
   - 错误码 `4`，文案 `reentrant call is not allowed`。
3. 唯一允许的提前终止方式是回调返回非 0：`feed` 返回 -1，错误码 `3`，文案 `callback aborted`。
4. 终止后 `reset()` 可复用 parser（禁止重入不等于禁止终止后复用）。
5. 不做重入支持的理由：回调期间半解析状态被外部改写需要复制或排队，与「纯协议解析器」的定位不符；
   停止的需求已由返回值覆盖。

### A-2 可观测性边界（第 12 题裁定）

1. **不提供只读视察接口**：不为测试在产品里开口子，生成头不增加查询/调试方法。
2. `finish()` 的清理只用两类证据：分配计数快照（`finish` 前后未释放块数与字节数不增，销毁后归零）
   与行为断言（之后 `feed` 不再触发事件、`reset` 后重喂不带旧内容）。
3. 块内残留长度（`line_len` / `data_len` / `event_len`）**不可观测**：计数器只看分配块大小，
   在不加接口的前提下无法直接断言；登记为不可观测，只由行为用例覆盖。不得用内部字段绕过。

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

### R-1 注册表行为

1. `init()` 归零 `count`/`err`/全部槽位，并按值返回宿主。
2. `reg(name, fn)` 按值返回宿主；同名键已存在时**不覆盖**，置 `err=2`，条目数不变（首个注册生效）。
3. `reg` 达到 8 条后再注册，置 `err=3`，条目数不变。
4. `make(name)` 命中时置 `err=0` 并返回构造结果；缺失时返回 0、置 `err=1`。
5. `name` 是借用指针，不复制；必须是字面量或静态存储。
6. `error()` 反映最近一次 `reg`/`make`/`init` 的结果；`err` 值 0/1/2/3 冻结。
7. 方法结果不能作下一跳接收者（SH-73），示例必须逐句落变量。

### R-2 retry 查询（第 4 题裁定）

1. `has_retry()` 返回 0/1，表示本流是否已有合法的 `retry` 字段。
2. `retry_hint()` 的返回值只在 `has_retry() == 1` 时有意义；调用方必须先判 `has_retry()`，不得直接使用未设置时的返回值。
3. `retry: 0` 是合法已设置值：`has_retry() == 1`、`retry_hint() == 0`。
4. 后续事件未再出现 `retry` 字段时，仍保持已设置（`has_retry() == 1`）。
5. `reset()` 保留 retry 及有效性（同 F-3）。

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
| S3 | event/id/retry 语义 + `s3_*` 夹具 | `bash test/run.sh s3_fields`；`bash test/run.sh s3_retry_zero` | `feat(sse): S3 字段语义` | M | 是 |
| S4 | 跨分片行结束 + BOM + `s4_*` 夹具 | `bash test/run.sh s4_chunk` | `feat(sse): S4 分片与 BOM` | M | 是 |
| S5 | 行上限/终止态 + `s5_*` 夹具 | `bash test/run.sh s5_limits` | `feat(sse): S5 限额与终止态` | M | 是 |
| S6 | `sse_event_copy`/`sse_event_free` + `s6_copy` 夹具 | `bash test/run.sh s6_copy` | `feat(sse): S6 拷贝出口` | M | 是 |
| S7 | README + 集成样例 + `s7_integration` 夹具 | `bash test/run.sh s7_integration` | `test(sse): S7 示例与文档` | S | 是 |
| S8 | 值返回注册表 + `s8_registry` 夹具 | `bash test/run.sh s8_registry` | `feat(sse): S8 值返回注册表` | M | 是 |
| S9 | 分配器注入、OOM/计数夹具 | `bash test/run.sh s9_oom`；`bash test/run.sh s9_alloc_count`；`bash test/run.sh s9_finish_clean` | `feat(sse): S9 分配器注入与计数` | M | 是 |
| I-1 | ct-http 真实链路（独立集成门禁，不并入单包门禁） | `bash test/integration.sh` | `test(sse): I-1 ct-http 真实对接` | M | 是 |
| S10 | 回调内重入拒绝 + `s10_reentrant` | `bash test/run.sh s10_reentrant` | `feat(sse): S10 回调重入保护` | M | 是 |

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
| E-10 | R-1 七条：缺失/重键/满/init/首条生效逐条有夹具断言 | `bash test/run.sh s8_registry` |
| E-11 | R-2 五条：未设置、`retry: 0`、跨事件保持、reset 保留逐条有夹具断言 | `bash test/run.sh s3_retry_zero` |
| E-12 | `max_line_bytes(n)` 的 `n` 是内容字节上限：恰好 `n` 字节通过、`n+1` 字节报错（以 `n=4096` 写死） | `bash test/run.sh s5_limits` |
| E-13 | 四处 OOM 注入（parser / 行缓冲 / data 缓冲 / `sse_event_copy`）分别断言失败返回值、`has_error()` 与 `out of memory` | `bash test/run.sh s9_oom` |
| E-14 | alloc/free 计数在整块、逐字节、伪随机三种切法下相等且 `live == 0`；文档写明只证明整块缓冲漏释放 | `bash test/run.sh s9_alloc_count` |
| E-15 | 四类记账写入门禁登记：两类环境缺口、ct/ct-ast 等价性不计入门禁通过数、并发为契约 | [S9-allocator](../reviews/S9-allocator.md) §5 人工核对 |
| E-16 | `finish()` 清理由计数快照（前后不增、销毁后归零）与行为断言共同证明；不加只读接口，块内残留长度登记为不可观测 | `bash test/run.sh s9_finish_clean`、[S9-allocator](../reviews/S9-allocator.md) §6 |
| E-17 | 真实 ct-http 发布版的 chunk 能驱动 `feed`：BOM 分片、data 跨 chunk、多行 data、id/retry 持久与空 id 清除、空行分发、EOF 丢弃 pending data | `bash test/integration.sh`、[S13-http-integration](../reviews/S13-http-integration.md) |
| E-18 | 回调内 `feed` / `reset` / `sse_parser_free` 各被拒绝（code 4、文案含 reentrant），之后 `reset` + `feed` 仍可用；回调返回非 0 → code 3，`reset` 后可复用 | `bash test/run.sh s10_reentrant` |

## 7 非目标

HTTP 传输、LLM 协议语义、重连策略、事件路由/多订阅、字符编码转换（BOM 除外）、线程安全、借用检查、方法级私有之外的可见性扩展、`Vec.data()` 语言请求。

## 8 变更记录

| 日期 | 变更 | 依据 |
| --- | --- | --- |
| 2026-11-15 | 首版冻结；相对提案修正 WHATWG W10、retry 0 值、静态工厂、行上限、分期 | S0-facts、S0-battle |
| 2026-11-15 | S6/S7 重切：原 S6（reset/finish）的行为已在 S1/S4/S5 落地，无独立红证可出；copy/free 移到 S6，README/集成样例移到 S7 | T-7 红证要求；E-5 需 copy 夹具 |
| 2026-11-15 | 新增 S8：负责人指定「注册表方法返回宿主自身」形态；实测 struct 按值返回可用，int 宿主无法承载注册表状态，故用 struct 宿主，保留 `sse_parser_new` 作为构造器函数值 | [S8-int-host](../reviews/S8-int-host.md)、`s8_registry` |
| 2026-11-15 | 第 4 题裁定：parser 的 retry 拆为 `has_retry()` + `retry_hint()`；`retry: 0` 为已设置；未设置时 hint 返回值不构成契约 | `s3_retry_zero`、R-2 |
| 2026-11-15 | 第 5 题裁定：`max_line_bytes(n)` 的 `n` 是内容字节上限（非含 NUL 容量）；恰好 `n` 合法、`n+1` 报错，判据以 `n=4096` 写死 | `s5_limits`、E-12 |
| 2026-11-15 | 第 6/7 题：新增 S9 分配器注入与 OOM/计数夹具；新增 `sse_parser_free` 作为漏斗内销毁出口；并发边界写成契约 C-1 | [S9-allocator](../reviews/S9-allocator.md)、E-13/E-14 |
| 2026-11-15 | 第 8 题：四类记账（退出可达内存、真实网络分片为环境缺口；ct/ct-ast 等价性登记；并发为契约）写入门禁登记 | [S9-allocator](../reviews/S9-allocator.md) §5、E-15 |
| 2026-11-15 | 第 12 题：不加只读视察接口；`finish()` 清理由计数快照与行为断言证明，块内残留长度登记为不可观测 | `s9_finish_clean`、A-2、E-16 |
| 2026-11-15 | 第 13 题：真实 ct-http 0.1.0（`ct get` 发布版）→ `sse_parser` 链路跑通；`-I vendor/http` 为包根绕法，待 `ct install` 修复后回退 | [S13-http-integration](../reviews/S13-http-integration.md)、I-1、E-17 |
| 2026-11-15 | 第 15 题：回调内禁止重入（生产构建同样检查），错误码 4；新增 `error_code()`；终止后 reset 可复用 | `s10_reentrant`、C-2、E-18 |
| 2026-11-15 | 第 14 题：新增 `s2_syntax`、`s3_state`、`s4_bom_edge`、`s9_error_codes`、`s10_reentrant_state`，补强 `s8_registry`；无独立用例项见 §9 | [S14-coverage](../reviews/S14-coverage.md) |

## 9 覆盖标注（附录，不改变 §2–§4 的任何口径）

> 依据：[S14-coverage](../reviews/S14-coverage.md) 的两席 battle。下列条目**没有独立夹具**，
> 不得写成「已覆盖」。它们要么不可观测，要么构造即 UB/编译期限制，要么证据形态是命令而非夹具。

| # | 条目 | 标注 | 理由 |
| --- | --- | --- | --- |
| 9-1 | `reset()` 清 `saw_cr` | 无独立用例 | 清与不清只差一个被吞掉的空行，空行不分发；无可观察差异 |
| 9-2 | `reset()` 保留缓冲容量 | 无独立用例 | A-2 不提供只读接口；计数器只看分配块大小 |
| 9-3 | 分配钩子不进生成头/公开 ABI | 无独立用例 | 证据是 `grep`/`nm` 命令（[S9](S9-allocator.md) §1），不是运行期夹具 |
| 9-4 | `sse_parser_free` 不与 `delete` 并用；回调不得 free 字段；`sse_event_free` 只接受 copy | 无独立用例 | 误用即 UB，用例只能验证崩溃，不能定义行为 |
| 9-5 | 块内残留长度（`line_len`/`data_len`/`event_len`） | 无独立用例 | 第 12 题裁定不加只读接口；只由计数快照与行为断言覆盖 |
| 9-6 | 同一 parser 不得多线程并发 | 无独立用例 | 契约而非未测（C-1）；单线程夹具证明不了「不得」 |
| 9-7 | 注册表 `name` 是借用、不复制 | 无独立用例 | 构造「释放后仍被读」只能制造 UB |
| 9-8 | 注册表方法结果不能作下一跳接收者 | 无独立用例 | 编译期限制；现有门禁没有编译负例通道，README 示例逐句落变量 |
| 9-9 | 视图失效方式（是否复用同一指针） | 无独立用例 | 契约只承诺有效期上限；断言复用会绑定实现。`delete` 后 UAF 已有 ASan 负例 |

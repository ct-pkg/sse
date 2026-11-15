# S0 两席 battle 与逐条裁定

> 两席：甲席＝协议合规（WHATWG HTML §9.2.6 事件流解释）；乙席＝工程可行（ct v0.53.0、内存模型、分期）。
> 裁判：主编。裁定只取三值：**成立 / 有条件成立 / 不成立**。每条给出可验证依据与改后口径。
> 事实依据：[S0-facts.md](S0-facts.md)。

## 0 基准：WHATWG 的完整规则集（10 条）

甲席先固定判据，避免「7 条」这种无法核对的提法：

| # | 规则 |
| --- | --- |
| W1 | 行分隔符为 CRLF、单 CR、单 LF 三种；CRLF 可跨分片 |
| W2 | 行首 `:` 是注释，整行忽略 |
| W3 | 字段按**第一个** `:` 切分；值前**只去掉一个**空格；无冒号行＝字段名 + 空值；未知字段忽略 |
| W4 | `data` 每次追加「值 + 一个 LF」；dispatch 时**只去掉一个**末尾 LF |
| W5 | 事件块内**从未出现 `data` 字段**才不分发；`data:` 产生空 data 事件 |
| W6 | `event` 缺省/空值回落 `message`；dispatch 后清空（无 data 的块也要清空） |
| W7 | `id` 跨事件持久；空值清除；值含 U+0000 整条忽略；取值为 dispatch 时刻 |
| W8 | `retry` 只接受纯 ASCII 数字，否则忽略；跨事件持久；`retry: 0` 合法 |
| W9 | 流首一个 U+FEFF BOM 忽略 |
| W10 | **到达 EOF 时丢弃任何 pending data（流末不完整事件不分发）** |

## 1 逐条裁定

### B-1 「WHATWG 7 条合规点完整正确」→ **不成立**

- 甲席：提案的 7 条覆盖了 W1–W7 的主体，但漏 W9、W10，且 W8 被写成「`strtol` + 尾部校验」，会接受 `+5`、`-1`、前导空白——这不是「只 ASCII 数字」。W5 的判定在提案里靠「data 缓冲长度为 0」，实现恰好正确但语义没写死。W7 的 NUL 检查没进代码。
- 乙席：更严重的是 `finish()` 与 W10 相反：提案 §5.7 在流末把残留行解析并分发最后一个事件。WHATWG 明确写「If the file ends in mid-event, the last event is not dispatched」。
- 裁定：**不成立**。改后口径：以 W1–W10 十条为唯一合规清单；`finish()` 改为 EOF 丢弃语义；`retry` 改为纯数字校验；`retry: 0` 合法；`id` 做 NUL 检查；BOM 必须实现。

### B-2 「`feed` 返回值与回调中断语义」→ **有条件成立**

- 甲席：`feed` 成功返回本次触发事件数、致命错误返回 -1，可判定；但提案把「回调返回非 0」也折成 -1 并写 `error_msg`，调用方无法区分「协议/资源致命」与「自己要求停」。
- 乙席：A 方案（-1 + `has_error()`）已被需求层冻结，可用；关键是把**终止态**写死：一旦 -1，后续 `feed`/`finish` 立即 -1，直到 `reset()`。否则 ct-http 的 chunk 回调可能继续喂数据，解析器在半状态上继续跑。
- 裁定：**有条件成立**。条件：①成功返回 `>=0` 计数；②任何致命（行超限/OOM/回调中断/已 finish）返回 -1 并置 `has_error()==1`；③进入终止态，`feed`/`finish` 幂等返回 -1，`reset()` 是唯一出口；④回调非 0 的中断错误文本固定为 `callback aborted`，用文本区分用户中断与协议错误；⑤本块剩余字节不再解析。

### B-3 「borrow 视图 + 深拷贝出口」所有权契约 → **有条件成立**

- 甲席：视图只读、回调返回即失效，配合 `sse_event_copy`/`sse_event_free` 是自洽的；但契约五条缺少「视图在**下一次 parser 调用**（不止回调返回）后失效」以及「copy 的结果必须且只能用 `sse_event_free` 释放」。
- 乙席：可测性足够：负例 1（保存指针→喂第二事件→指针内容被改写）；负例 2（ASan 保存指针→`delete`→读→heap-use-after-free）；正例（copy→`delete` parser→副本仍可读，无泄漏）。风险是 `sse_event_free` 被误用于 borrow 视图；用命名与文档固定，不引入所有权检查。
- 裁定：**有条件成立**。条件：①`SseEvent` 无 `Drop`；②视图有效期到「回调返回或下一次 `feed`/`finish`/`reset`/`delete` 中较早者」；③`sse_event_copy` 深拷贝 `event/data/id`（`data` 按 `data_len` 拷贝并补 NUL），OOM 返回 0；④`sse_event_free` 只接受 copy 返回值，先释放字段再释放结构；⑤README 列全五条 + 两条补充；⑥上述三条用例进夹具。

### B-4 「S0–S7 分期」→ **不成立**

- 甲席：S2「行缓冲 + 字段解析」没有任何可观察出口，必须等 S3 才能验收，违反「每相独立验收」。
- 乙席：S7 把「测试/文档」当独立实现相，且 S5/S6 的边界（限额、reset、finish）留到最后，前相会带错误假设推进。
- 裁定：**不成立**，重切为：
  | 相 | 目标 | 独立验收 |
  | --- | --- | --- |
  | S0 | 契约冻结 | 本卡 + 事实报告 + battle 报告 |
  | S1 | 类型/构造/Drop/错误查询骨架 | 构造、查询、`delete`（ASan） |
  | S2 | 行切分 + 字段解析 + data 事件分发（最小闭环） | WHATWG 基本例 1 事件、`data_len==10` |
  | S3 | event/id/retry 语义与 dispatch 清空 | 字段真值表用例 |
  | S4 | 跨 chunk 半行、CRLF/CR 跨分片、BOM | 逐字节 feed 与整块 feed 序列一致 |
  | S5 | 行上限、终止态、OOM 分支 | 边界 n-1/n/n+1 与 -1 后幂等 |
  | S6 | `reset` 复用、`finish` EOF 丢弃、状态查询 | 复用与 EOF 用例 |
  | S7 | `sse_event_copy/free`、README、集成样例 | ASan 正负例 + 桩集成样例 |

### B-5 「`SseParser::new()` 静态工厂」→ **不成立**

- 乙席：事实报告 §1.4/§1.5：非泛型静态方法调用面是 `Type.name()`；带 namespace 时三种写法全报错。提案的 `SseParser::new()` 在 v0.53.0 双重不可用。
- 裁定：**不成立**。改后口径：`pub SseParser *sse_parser_new(void)` 自由函数；包单元 `namespace sse;`、路径 `sse/sse.h.ct`；消费方 `sse::sse_parser_new()`。

### B-6 「retry 流级持久 + 0 表示未设置」→ **有条件成立**

- 甲席：流级持久正确（提案原文错误，需求层已纠正）。但「0＝未设置」与 W8 的 `retry: 0` 合法冲突：服务端下发 0 时 `has_retry()` 为假、`retry_hint()` 与「从未下发」不可区分。
- 乙席：加 `_retry_valid` 标志即可，不动公开结构；`SseEvent.retry` 用 `-1` 表示未设置，`has_retry()` 判 `>= 0`。
- 裁定：**有条件成立**。条件：①只接受非空纯 ASCII 数字，溢出忽略；②`retry: 0` 合法并置有效；③`retry_hint()` 未设置返回 -1；④`reset()` 保留 retry（重连建议跨流）；⑤用例覆盖 0、前导零、`+5`、`-1`、超长数字。

### B-7 「不要求 CT 新增能力」→ **有条件成立**

- 乙席：不需要改语言，但依赖三个绕法，提案没写：
  1. 带 namespace 的单元不能用静态固有方法 → 自由构造函数；
  2. impl helper 没有前向声明 → helper 必须先定义；
  3. helper 方法名不能以 `_` 开头（`_grow` 报 `no method`）→ 去掉前导下划线。
- 裁定：**有条件成立**。三个绕法必须写进 README/S0 卡，不能含糊成「已具备」。

### B-8 「错误用 `int` 返回 + `error_msg()`，不依赖 errdefer」→ **成立**

- 乙席：`.h.ct` 禁止 errdefer，普通返回码不触发 errdefer；本包实现只能在 `.h.ct`，提案选择正确。
- 裁定：**成立**。错误文本固定四类：`SSE line exceeds <n> bytes`、`out of memory`、`callback aborted`、`parser finished`。

### B-9 「`max_line_bytes(n)`」→ **不成立（原口径歧义）**

- 乙席：提案判据 `_line_len + 1 >= _max_line_bytes` 把 n 当「含 NUL 的容量」，文档却写「行上限 64KB」，边界不可核对。
- 裁定：**不成立**，改后口径：`n` = 单行**内容字节**上限，`n >= 1`，默认 65536；恰好 n 字节的行通过，第 n+1 字节触发 -1；`n <= 0` 返回 -1 且保留旧值。

### B-10 「公开 API 面」→ **有条件成立**

- 甲席：提案的 10 个方法 + 3 个查询可用，但 `_xxx` 私有假设错误，且没列 `sse_parser_new`/copy/free。
- 裁定：**有条件成立**。冻结清单见 [S0 卡](../phases/S0/card.md) §3；清单外符号一律私有；私有 helper 不进生成头。

### B-11 「`sse_event_copy` / `sse_event_free`」→ **有条件成立**

- 乙席：`SseEvent *sse_event_copy(SseEvent *ev)` 返回堆对象可行（实测无 CT 泄漏告警）；`data` 必须按 `data_len` 拷贝（可含 NUL）并补结尾 NUL。
- 裁定：**有条件成立**。条件：copy 失败返回 0；free 只接受 copy 结果；`id==0` 时副本 `id==0`；`retry` 原样（含 -1）。

### B-12 「定位为纯协议解析器」→ **成立**

- 不做 HTTP、不做 LLM 语义、不做重连、不做路由；只输出 `SseEvent`。裁定：**成立**。

### B-13 「请 CT 组给 `Vec<T>.data()`」→ **不成立（撤回）**

- 乙席：v0.53.0 的 `Vec` 无 `data()`/`ptr()`，只有拷贝语义的 `get`；本包已决定不用 `Vec`。
- 裁定：**不成立**，从提案中撤回该请求，不作为本包依赖。

## 2 裁定汇总

| 条目 | 裁定 |
| --- | --- |
| B-1 WHATWG 7 条 | 不成立 |
| B-2 feed/中断 | 有条件成立 |
| B-3 borrow/copy 契约 | 有条件成立 |
| B-4 S0–S7 分期 | 不成立 |
| B-5 静态工厂 | 不成立 |
| B-6 retry 流级与 0 值 | 有条件成立 |
| B-7 不新增语言能力 | 有条件成立 |
| B-8 int 返回 + 错误文本 | 成立 |
| B-9 行上限 | 不成立 |
| B-10 公开 API 面 | 有条件成立 |
| B-11 copy/free | 有条件成立 |
| B-12 定位 | 成立 |
| B-13 Vec.data() | 不成立（撤回） |

**结论：提案不能按原文开工；按 §1 的改后口径冻结 S0 后再进 S1。**

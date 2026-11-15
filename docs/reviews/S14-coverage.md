# S14：契约细则的夹具覆盖表（两席 battle 结论）

> 日期：2026-11-15。契约：[S0 card](../phases/S0/card.md) §3/§4。
> 范围：把契约里**可判定**的细则逐条摘出，标出现有夹具是直接覆盖、间接覆盖，还是无夹具；
> 两席就「必须补夹具 / 可以只写文档」对打；结论落到夹具与契约标注。
> 判据只有两条：①这条错了会不会**静默产生错误事件**；②构造夹具的成本。

## 1 结论摘要

- 新增 5 个夹具：`s2_syntax`、`s3_state`、`s4_bom_edge`、`s9_error_codes`、
  `s10_reentrant_state`；另补强 `s8_registry`（重键 `err=2` 的直接断言）。
- 判定「只写文档」的 9 条，逐条在 [S0 card](../phases/S0/card.md) §9 标注「无独立用例」并给出理由。
- 不造只断言常量、只重复已有行为的用例；所有新用例都锚定一条会改变事件内容或错误码的细则。

## 2 完整清单与现状

状态含义：
- **直接**：夹具里有独立的输入与断言，能单独变红。
- **间接**：由别的用例顺带覆盖，删掉该条仍可能全绿。
- **无**：没有夹具。

### 2.1 W1–W10（WHATWG 十条）

| 编号 | 可判定细则 | 现有证据 | 状态 | 处置 |
| --- | --- | --- | --- | --- |
| W1-a | CRLF 行结束 | `s4_chunk`：`data: a\r` + `\n\r\n` → 1 事件 | 直接 | 保留 |
| W1-b | 单 CR 行结束 | `s4_chunk`：`data: b\r\r` → b | 直接 | 保留 |
| W1-c | 单 LF 行结束 | `s2_basic`、`s4_chunk` | 直接 | 保留 |
| W1-d | CRLF 可跨 `feed`（CR 在块尾、LF 在下一块） | `s4_chunk` 同一用例 | 直接 | 保留 |
| W1-e | CR 后紧跟非 LF：CR 即行结束，不吞下一字符 | `s4_chunk`：`\r\r` 后的 `data: c` 正常 | 间接 | 保留（行为已由同一事件数锁住） |
| W2-a | 行首 `:` 整行忽略 | `s7_integration`、`s9_alloc_count` 的 `: keepalive` | 直接 | 保留 |
| W2-b | 注释行内含冒号仍整行忽略 | 无 | **无** | 补 `s2_syntax`：`:data: x` → 0 事件 |
| W3-a | 按**第一个**冒号切分 | 无（`s7` 的注释不走切分） | **无** | 补 `s2_syntax`：`data: a:b:c` → `a:b:c` |
| W3-b | 值前**只去一个**空格 | 无（现有用例都只有一个空格） | **无** | 补 `s2_syntax`：`data:  x` → `" x"` |
| W3-c | 无冒号行 = 字段名 + 空值 | `s5_limits` 的 `12345678` 只证明未知字段忽略 | 间接 | 补 `s2_syntax`：`data` → 空 data 事件 |
| W3-d | 未知字段忽略 | `s5_limits`、`s2_basic`（`event: ping\n\n` 0 事件） | 直接 | 补 `s2_syntax` 的 `foo: bar` 作同句断言 |
| W3-e | 字段名大小写敏感 | 无 | **无** | 补 `s2_syntax`：`Data: x` → 0 事件 |
| W4-a | 多行 data 用 LF 连接，分发时只去一个末尾 LF | `s2_basic`：YHOO/+2/10 → `len=10` | 直接 | 保留 |
| W4-b | 末尾空 data 只去一个 LF（内部 LF 保留） | 无 | **无** | 补 `s2_syntax`：`data: a\ndata:` → `"a\n"` |
| W4-c | data 可含内嵌 NUL，按 `data_len` 读 | `s6_copy`：`a\0b` → `len=3`、字节 97/0/98 | 直接 | 保留 |
| W5-a | 出现过 `data` 字段就分发；`data:` 是空 data 事件 | `s2_basic`：`data:\n\n` → 1 事件、`len=0` | 直接 | 保留 |
| W5-b | 没有 `data` 字段的块不分发 | `s2_basic`、`s3_fields`（`event: ping\n\n` 0 事件） | 直接 | 保留 |
| W6-a | `event` 缺省 = `message` | `s2_basic`、`s3_fields` | 直接 | 保留 |
| W6-b | `event:` 空值 = `message` | `s3_fields` e3 | 直接 | 保留 |
| W6-c | dispatch 后清空 `event` | `s3_fields`：ping 之后的事件回落 message | 直接 | 保留 |
| W6-d | 无 data 的块也清空 `event` | `s3_fields`：`event: ghost\n\n` 后的事件为 message | 直接 | 保留 |
| W7-a | `id` 跨事件持久 | `s3_fields` e5 | 直接 | 保留 |
| W7-b | `id:` 空值清除 | `s3_fields`：`last_id_null=1` | 直接 | 保留 |
| W7-c | `id` 值含 NUL 整条忽略，保留前值 | `s3_fields`：`id_after_nul=1` | 直接 | 保留 |
| W7-d | 取值为 dispatch 时刻（同一块里 data 后的 id 仍生效） | 无 | **无** | 补 `s3_state` e2：`data: b\nid: 2` → id=2 |
| W7-e | `last_event_id()` 返回持久缓冲，空则 NULL | `s3_fields`、`s3_state` | 直接 | 保留 |
| W8-a | 只接受非空纯 ASCII 数字（`+5`/`-1`/`3x`/空值忽略） | `s3_fields` | 直接 | 保留 |
| W8-b | `retry: 0` 合法且为「已设置」 | `s3_retry_zero` | 直接 | 保留 |
| W8-c | 溢出（> `INT_MAX`）忽略，保留前值 | 无 | **无** | 补 `s3_state`：`2147483648` 后仍 1000 |
| W8-d | 前导零仍是合法数字 | 无 | **无** | 补 `s3_state`：`007` → 7 |
| W8-e | `retry` 跨事件持久 | `s3_retry_zero` | 直接 | 保留 |
| W8-f | `SseEvent.retry` 是 dispatch 时刻快照；未设置 = -1 | `s3_fields`、`s3_retry_zero` | 直接 | 保留 |
| W9-a | 流首 BOM 整块被吞 | `s4_chunk` e1 | 直接 | 保留 |
| W9-b | BOM 跨 3 个 feed 分片仍只剥一次 | `s4_chunk` e2 | 直接 | 保留 |
| W9-c | 首字节不是 BOM 时按普通字节回放 | `s4_chunk` e7（`d` + `ata: h`） | 直接 | 保留 |
| W9-d | `reset()` 后重新武装 BOM | `s4_chunk` 第三段 | 直接 | 保留 |
| W9-e | 流中再次出现 BOM 字节不得剥掉 | 无 | **无** | 补 `s4_bom_edge`：中段 BOM 行不分发 |
| W10-a | EOF 丢弃 pending 半行与未分发 data | `s6_finish_eof`、`s9_finish_clean` | 直接 | 保留 |
| W10-b | `finish` 后 `feed` = -1 + `parser finished` | `s1_construct`、`s6_finish_eof` | 直接 | 保留 |
| W10-c | 第二次 `finish` = -1 | `s1_construct`：`finish2=-1` | 直接 | 保留 |
| W10-d | `finish` 不隐式 reset/delete | `s1_construct`：feed 仍 -1、对象仍可 reset | 直接 | 保留 |

### 2.2 F-1–F-3（feed / finish / reset）

| 编号 | 可判定细则 | 现有证据 | 状态 | 处置 |
| --- | --- | --- | --- | --- |
| F-1-a | `feed(0,0)` = 0，不改变状态 | `s4_chunk`：`null_feed=0 n=7 err=0` | 直接 | 保留 |
| F-1-b | 成功返回**本次调用**事件数 | `s2_basic`、`s9_alloc_count`（累加） | 直接 | 保留 |
| F-1-c | 致命一律 -1 并进入终止态 | `s5_limits`、`s5_abort` | 直接 | 保留 |
| F-1-d | 终止态下 `feed`/`finish` 幂等 -1，唯一出口 `reset` | `s5_limits`、`s6_finish_eof` | 直接 | 保留 |
| F-1-e | 回调非 0 → 中断，本块剩余字节不再解析 | `s5_abort`：第二事件未分发 | 直接 | 保留 |
| F-1-f | 中断前已分发的事件照常计数，整体返回 -1 | `s5_abort`：`feed=-1 n=1` | 直接 | 保留 |
| F-2-a | `finish` 正常返回 0；错误态/已完成返回 -1 | `s1_construct`、`s6_finish_eof` | 直接 | 保留 |
| F-2-b | `finish` 保留 id/retry | 无（`s9_finish_clean` 只验证丢弃） | **无** | 补 `s3_state`：finish+reset 后 id=9、retry=7 |
| F-3-a | `reset` 清行/data/event/`has_data`/错误/finish 标志 | `s5_limits`、`s9_finish_clean`、`s1_construct` | 直接 | 保留 |
| F-3-b | `reset` 清 pending 半行，不污染下一事件 | `s9_finish_clean` 只到「有事件」；未断言事件内容 | 间接 | 补 `s3_state`：stale 行/半 data 后 reset，下一事件 event=message、data 干净 |
| F-3-c | `reset` 清 `saw_cr` | 无，且**构造不出可区分行为** | 无 | 只写文档（卡 §9-1） |
| F-3-d | `reset` 清 BOM 状态 | `s4_chunk` 第三段 | 直接 | 保留 |
| F-3-e | `reset` 保留 lastEventId | 无 | **无** | 补 `s3_state`：reset 后 `last_event_id` 仍 9 |
| F-3-f | `reset` 保留 retry 及有效性 | `s3_retry_zero` | 直接 | 保留 |
| F-3-g | `reset` 保留回调注册 | `s5_abort`：reset 后仍分发 | 直接 | 保留 |
| F-3-h | `reset` 保留 `max_line_bytes` | `s5_limits`：reset 后 8 字节通过、9 字节报错 | 直接 | 保留 |
| F-3-i | `reset` 保留缓冲容量（不释放） | 无 | 无 | 只写文档（卡 §9-2，A-2 不可观测） |

### 2.3 分配、所有权、并发、注册表、错误码

| 编号 | 可判定细则 | 现有证据 | 状态 | 处置 |
| --- | --- | --- | --- | --- |
| A-1-a | 所有分配经 alloc/free 漏斗 | `s9_alloc_count`、`s9_oom` | 直接 | 保留 |
| A-1-b | 钩子不进生成头、不进公开 ABI | `grep`/`nm` 证据（[S9](S9-allocator.md) §1） | 无夹具 | 只写文档（卡 §9-3：证据是命令，不是夹具） |
| A-1-c | 失败次数由运行期变量控制 | `s9_oom` 的 `g_fail_at` | 直接 | 保留 |
| A-1-d | `sse_parser_free` 在漏斗内销毁；不得与 `delete` 并用 | `s9_alloc_count`：`live=0` | 直接 / 误用无 | 误用只写文档（卡 §9-4） |
| A-2-a | 不提供只读视察接口 | 导出符号清单 | 无夹具 | 只写文档（第 12 题裁定；卡 §9-5） |
| A-2-b | `finish` 前后分配计数不增、销毁后归零 | `s9_finish_clean` | 直接 | 保留 |
| A-2-c | 块内残留长度不可观测 | 无 | 无 | 只写文档（卡 §9-5） |
| C-1 | 同一 parser 不得多线程并发；回调同步在 feed 线程 | 无 | 无 | 只写文档（契约，卡 §9-6） |
| C-2-a | 回调内 `feed` 被拒（code 4） | `s10_reentrant` | 直接 | 保留 |
| C-2-b | 回调内 `reset` 被拒（code 4）且未执行 | `s10_reentrant`：错误未被 reset 清掉 | 直接 | 保留 |
| C-2-c | 回调内 `sse_parser_free` 被拒（code 4） | `s10_reentrant` | 直接 | 保留 |
| C-2-d | 回调内 `finish` 被拒（code 4） | 无 | **无** | 补 `s10_reentrant_state` |
| C-2-e | 回调内 `on_event` 被拒，原回调未被替换 | 无 | **无** | 补 `s10_reentrant_state`（后续事件仍进原回调） |
| C-2-f | 回调内 `max_line_bytes` 被拒，限额未被改 | 无 | **无** | 补 `s10_reentrant_state`（后续 6 字节行仍通过） |
| C-2-g | 回调返回非 0 是唯一提前终止；reset 后可复用 | `s5_abort`、`s10_reentrant` | 直接 | 保留 |
| R-1-a | `init` 归零并返回宿主；`reg` 返回宿主 | `s8_registry` | 直接 | 保留 |
| R-1-b | 缺失键 → NULL + `err=1` | `s8_registry` | 直接 | 保留 |
| R-1-c | 同名键首条生效、不覆盖 + `err=2`、条目数不变 | `s8_registry` 只断言了 `d1=1 d2=0`；`err` 被随后的 `make` 重置 | 间接 | 补强：`dup_err=2 size=2` |
| R-1-d | 满 8 条后 `err=3`、条目数不变 | `s8_registry` | 直接 | 保留 |
| R-1-e | `make` 命中 `err=0`；缺失 `err=1` | `s8_registry` | 直接 | 保留 |
| R-1-f | `name` 是借用、不复制 | 无 | 无 | 只写文档（卡 §9-7：构造即 UB） |
| R-1-g | 方法结果不能作下一跳接收者 | README 示例逐句落变量 | 无夹具 | 只写文档（卡 §9-8：编译期限制，run.sh 不支持编译负例） |
| R-2-a | `has_retry()` 0/1；未设置时 `retry_hint()` 不构成契约 | `s3_retry_zero` | 直接 | 保留 |
| R-2-b | `retry: 0` → `has_retry=1`、`hint=0`、跨事件与 reset 保持 | `s3_retry_zero` | 直接 | 保留 |
| X-1-a | 行超限文本含当前上限 | `s5_limits`（8 / 4096） | 直接 | 保留 |
| X-1-b | `out of memory` / `callback aborted` / `parser finished` / 重入文本 | `s9_oom`、`s5_abort`、`s1_construct`、`s10_reentrant` | 直接 | 保留 |
| X-1-c | `error_code()` 的 0/1/2/3/4/5 各自可断言 | 只有 3、4 被直接断言；1/2/5 只断言了文本 | 间接 | 补 `s9_error_codes`：1/5/3/4/2/0 逐个打印 |
| X-1-d | 协议非致命（未知字段/非法 retry/注释/NUL id）不置错 | `s3_fields`、`s2_syntax` | 直接 | 保留 |
| M-1-a | 视图只在回调内有效；下一次 feed 后失效 | `s6_borrow_uaf` 只覆盖 delete 后 UAF | 间接 | 不补「必须复用同一指针」用例：契约只保证有效期上限，断言复用会绑定实现；delete 后 UAF 已由 ASan 覆盖（卡 §9-9） |
| M-1-b | 跨回调保留必须 copy；copy 在 delete 后仍可读 | `s6_copy` | 直接 | 保留 |
| M-1-c | 回调不得 free 字段 / `sse_event_free` 只接受 copy | 无 | 无 | 只写文档（卡 §9-4：误用即 UB，用例只能验证崩溃） |
| M-1-d | `delete` 后任何未 copy 的视图悬垂 | `s6_borrow_uaf`（ASan） | 直接 | 保留 |

## 3 两席 battle

**甲席（静默错误席）**：判据只有一条——这条错了，会不会产出一个「格式合法但内容错误」的事件，
让调用方无法察觉？

> 必须补的：W2-b、W3-a/b/c/e、W4-b、W7-d、W8-c/d、W9-e、F-2-b、F-3-b/e、C-2-d/e/f、R-1-c、X-1-c。
> 这些都是「不报错、但事件内容或错误码错了」的形态：注释被当字段、两个空格被吃成一个、
> 值里第二个冒号被截断、大小写被当成同名字段、末尾 LF 被 trim 光、id 在块首就被快照、
> retry 溢出被回绕、中段 BOM 被剥、finish 把重连状态清掉、reset 把半行拼进下一事件、
> 某条重入路径未守、重键静默覆盖、错误码永远是老值。
> 成本都是「一个夹具、几十行、一条命令」，没有理由不补。

**乙席（可观测/成本席）**：同意上面全部，但以下五类不该做夹具：

> 1. `reset` 清 `saw_cr`：清与不清只在「reset 后的第一个字节是 LF、且上一流以 CR 结尾」时
>    差一个空行；空行本身不分发，**没有任何可观察差异**，构造不出会红的用例。
> 2. 缓冲容量保留、块内残留长度：第 12 题已裁定不加只读接口，计数器只看块大小，
>    **不可观测**；用内部字段断言等于绕过裁定。
> 3. `name` 借用、回调 free 字段、`sse_event_free` 误用：要么是 UB，要么构造即崩溃，
>    只能写成契约，不能写成「期望输出」。
> 4. 「视图必须在下次 feed 后失效」的指针复用断言：契约只承诺有效期上限，不承诺失效方式；
>    断言必须复用同一块内存会把实现细节写成契约。delete 后 UAF 已由 ASan 负例覆盖。
> 5. 并发与「方法结果不能链式」：单线程夹具与现有 run.sh 都证明不了；前者是契约，
>    后者是编译期限制。要证明只能加编译负例门禁，成本高于收益。

**裁判结论**：甲席的 16 条全部补；乙席的 5 类全部只写文档，并在契约里逐条标
「无独立用例」+ 理由。没有「先放着」的中间态。

## 4 新夹具与判据

| 夹具 | 覆盖 | 验收命令 | 关键断言 |
| --- | --- | --- | --- |
| `s2_syntax` | W2-b、W3-a/b/c/d/e、W4-b | `bash test/run.sh s2_syntax` | `:data: x` 0 事件；`data:  x` → `" x"`；`data: a:b:c` 全值；`data` → 空事件；`Data: x` 0 事件；`data: a\ndata:` → `"a\n"` |
| `s3_state` | W7-d、W8-c/d、F-2-b、F-3-b/e | `bash test/run.sh s3_state` | 同块 data 后的 id=2；溢出后仍 1000；`007`→7；finish+reset 后 id/retry 保留；stale 半行不污染下一事件 |
| `s4_bom_edge` | W9-e | `bash test/run.sh s4_bom_edge` | 中段 BOM 行 0 事件，随后 `data: c` 正常 |
| `s9_error_codes` | X-1-c | `bash test/run.sh s9_error_codes` | code 1/5/3/4/2/0 逐条打印；OOM 后 reset 可恢复 |
| `s10_reentrant_state` | C-2-d/e/f | `bash test/run.sh s10_reentrant_state` | finish/on_event/max_line_bytes 在回调内均 -1、code 4；后续事件仍进原回调、6 字节行仍通过 |
| `s8_registry`（补强） | R-1-c | `bash test/run.sh s8_registry` | `dup_err=2 size=2` 直接断言重键错误码 |

### 4.1 红证顺序（如实登记）

这 5 个新夹具与 1 处补强**首跑即绿**：现有实现已经正确，新增的是「锁」，不是「修」。
按 T-7，红证应先行；这里无法制造真红——要让它们红，必须先破坏已经交付并通过门禁的实现，
与「已有实现不推倒重来」直接冲突。因此按「先实现、后发现需补卡」的顺序登记：

- 红证基线：不适用（无失败提交）。
- 首次绿灯：见 §5 的原始输出。
- 补偿：每条新断言都对应一条会静默出错的细则（§3 甲席清单），不是复述已有输出。

`test/run.sh` 仍对每个夹具做 `-Wall -Wextra -Werror`、拒绝 `warning:`、逐字节 diff。

## 5 原始输出

```console
$ bash test/run.sh s2_syntax
ok s2_syntax
$ bash test/run.sh s3_state
ok s3_state
$ bash test/run.sh s4_bom_edge
ok s4_bom_edge
$ bash test/run.sh s9_error_codes
ok s9_error_codes
$ bash test/run.sh s10_reentrant_state
ok s10_reentrant_state
$ bash test/run.sh s8_registry
ok s8_registry
```

## 6 只写文档的条目（契约标注见 S0 卡 §9）

| # | 条目 | 为什么无独立用例 |
| --- | --- | --- |
| 9-1 | `reset` 清 `saw_cr` | 唯一差异是吞掉一个空行，而空行不分发；无可观察行为 |
| 9-2 | `reset` 保留缓冲容量 | 无只读接口，计数器只看块大小（第 12 题裁定） |
| 9-3 | 分配钩子不进生成头/ABI | 证据是 `grep`/`nm` 命令，不是运行期夹具 |
| 9-4 | `sse_parser_free` 不与 `delete` 并用；回调不得 free 字段 | 误用即 UB；用例只能证明崩溃，不能定义行为 |
| 9-5 | 不提供只读视察接口；块内残留长度不可观测 | 第 12 题裁定：不为测试在产品里开口子 |
| 9-6 | 并发契约（同 parser 不得多线程并发） | 单线程夹具证明不了「不得」；写成契约 |
| 9-7 | 注册表 `name` 借用不复制 | 构造「释放后仍被读」只能制造 UB |
| 9-8 | 注册表方法结果不能作下一跳接收者 | 编译期限制；现有门禁没有编译负例通道 |
| 9-9 | 视图失效方式（是否复用同一指针） | 契约只承诺有效期上限；断言复用会绑定实现 |

## 7 不做的事

- 没有新增「只断言常量」的用例（例如只打印默认上限 65536）。
- 没有把 `s6_copy`/`s2_basic` 已有行为换个名字再写一遍。
- 没有为「覆盖率数字」添加不会改变任何断言的夹具。

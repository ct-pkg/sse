# ct-sse 提案分析

> 范围：只读分析。不建仓库、不写实现、不出正式 phase 卡、不改 ct-lang 跟踪文件。
> 依据：ct-lang HEAD（2026-11-13）与提案要点（OO 版，S1–S7）。

## 1 一句话结论

**不能按原样立项。** 先改四处再开工：`_set_error` 不能是 struct 方法（变参方法被硬拒）；
`_xxx` 在同一 `.h.ct` 内不是私有方法（`pub struct` 的 impl 方法会全部进生成头）；`retry` 是流级状态、
不是“当前事件有效”；`feed` 的返回值契约与回调中断语义二选一。其余按 S1–S7 可推进，但要先补
WHATWG 的 `id` 清除、`data:` 空事件与行上限边界。

## 2 假设核验（8 行）

| # | 假设 | 结论 | 证据 | 若不成立怎么降级 |
| --- | --- | --- | --- | --- |
| 1 | 可定义 `int _set_error(char *fmt, ...)` 并转发 `vsnprintf` | **成立，但只能是自由函数**。CT 支持用户定义变参函数、`va_list`、`va_start`、`va_arg`、`vsnprintf`；struct 方法（含固有 impl）带 `...` 被硬拒 | `test/ast/38_variadic/prog.ct:7-21`；`examples/tour/11_variadic/forward/prog.ct:24-31`；`selfhost/ct-ast/frontend/parse/Parser.h.ct:3153-3155`、`:3497-3499`；`test/ast/errors/variadic_impl.ct:11-13` | 写成 `.ct` 里的 `static int sse_set_error(SseParser *p, char *fmt, ...)`；不要放进 `impl SseParser` |
| 2 | `pub struct` / `pub typedef` 的包内/跨包可见性如提案假设 | **半成立**。`pub` 类型进入依赖单元生成头、按 import 传递闭包可见；跨“包”没有编译器 ACL，只有 import + `pub`。**同一 `.h.ct` 内 `pub struct` 的 impl 方法全部会进入生成头**，`_xxx` 不是私有 | `docs/language-spec.md:598-600`、`:1554-1555`；`selfhost/ct-ast/backend/emit/Emitter.h.ct:3328-3353`、`:3235-3244` | 把 `_xxx` 改成 `.ct` 内的 `static` 自由函数；或接受它们进入公开 API 并在文档列出 |
| 3 | 字段以 `_` 开头有保留/私有语义 | **不成立（字段）**。词法只要求 `[A-Za-z_][A-Za-z0-9_]*`，CT 不把前导 `_` 当私有；结构体成员不是文件作用域，C 的保留规则不命中。**但文件作用域的 `_set_error` 命中 C“下划线+小写”保留** | `docs/language-spec.md:63-64`；`selfhost/ct-ast/frontend/lex/Lexer.h.ct:102-107` | 字段 `_x` 可留；文件作用域函数改名 `sse_set_error`，避免 C 实现保留名 |
| 4 | `calloc` 赋给 `struct SseParser *` 要显式转型；`free` 包内可直接用 | **不需要转型**（C 的 `void *` 隐式转对象指针）；`free` 需要 `#include <stdlib.h>`，不是 CT 内建。注意：加转型会让 `own` 的分配识别失效 | `selfhost/ct-ast/backend/mem/Memory.h.ct:119-127`（`malloc`/`calloc` 裸调用才被识别）；`test/ast/231_str_ops/prog.ct:5,21`（stdlib + free） | 不加转型；在 `.ct`/`.h.ct` 写 `#include <stdlib.h>`；工厂返回值用 `delete`，不要 `own` |
| 5 | `strncmp`/`strtol`/`memcpy`/`vsnprintf`/`INT_MAX` 可直接用 | **成立，按 C 头补齐即可**：`<string.h>`、`<stdlib.h>`、`<stdio.h>`、`<stdarg.h>`、`<limits.h>`。仓库已有 `memcpy` + `<string.h>` 的先例；生成头不携带 `#include` | `lib/std/Vec.h.ct:19`、`:79`；`examples/tour/11_variadic/forward/prog.ct:9-10`；`selfhost/ct-ast/backend/emit/Emitter.h.ct:10-11` | 全部 include 放在 `.ct`；不要把 `INT_MAX`/`vsnprintf` 放进会落到生成 `.h` 的内联体 |
| 6 | `SseParser` 内嵌 `SseEvent _current;` 与 `use Drop` 组合安全 | **成立**。显式 `impl Drop` 时不生成字段递归 glue；`SseEvent` 本身无 Drop，`_current` 不会被递归清理 | `selfhost/ct-ast/backend/emit/Emitter.h.ct:2881-2896`（有显式 impl 则 `continue`）、`:2901-2918`（仅对 `uses_drop` 字段生成 glue） | 保持 `SseEvent` 无 `use Drop`；若将来加，必须在 parser 的 `drop` 里显式处理，别指望 glue |
| 7 | 方法体可写 `self->_x`；静态方法不能用 `self` | **成立**。impl 方法内 `self` 被重写为 `_self`（指针）；`static` 方法落码无 `self` 参数 | `docs/language-spec.md:174-177`、`:2083-2086`；`selfhost/ct-ast/backend/emit/Emitter.h.ct:3340-3344` | `new()` 用局部 `SseParser *p`；`_x` 统一经 `p->_x`，不要在 static 里写 `self` |
| 8 | `impl Drop for T { void drop() }` + `} use Drop;` 在含指针字段的 parser 上无额外限制 | **成立**。`delete p` 发射 `if (p) { T_Drop_drop(p); free(p); p = 0; }`；`drop` 只负责内部缓冲区，不 `free(self)` | `selfhost/ct-ast/backend/emit/Emitter.h.ct:3501-3518`；`examples/tour/15_memory/manual_shim/main.ct:19` | 与 ct-http 同一套；显式 `drop` 里释放 `_line`/`_data`/`_event`，不要释放 `_current` 的借用指针 |

## 3 风险表（按严重度排序）

| 严重度 | 风险 | 故障形态 | 最小防线 |
| --- | --- | --- | --- |
| 高 | `SseEvent` 字段借用 parser 缓冲，回调返回即失效 | 回调把 `ev->data`/`ev->event` 存进列表或全局；下一次 `feed` 复用 `_data`、`realloc` 搬移、或 `reset`/`delete` 释放后，读到新事件数据或已释放内存（ASan 下 heap-use-after-free），普通构建下静默串数据。与 L4 同类：契约不是编译器检查 | 契约写“只在回调内有效”；提供 `sse_event_copy(ev)` 深拷贝；负例：回调存指针→喂第二个事件→断言第一个指针内容已变；再加 `-fsanitize=address` 的 delete 后读取用例 |
| 高 | `_data` 缓冲区事件后 `_data_len=0` 复用 | 调用方在回调里存 `ev->data`，第二事件复用同一块内存并改写；表现为“上一条消息内容突然变成下一条” | 与上条共用 copy API；负例固定为同一 `feed` 块内两个事件，断言第一个存下的指针与第二个 `ev->data` 相同且内容不同；测试必须红 |
| 高 | `_dispatch_event` 把回调非 0 转成 `_set_error("callback aborted")` 返回 -1，但 `feed` 契约写“返回回调次数” | 调用方按“次数”使用 -1（当成负数计数）或忽略错误继续 `feed`；错误状态与返回值两套语义，无法判断是否应停止 | 冻结一条：`feed` 成功返回 `>=0` 的事件数，任何错误（含回调中断）返回 `-1` 并置 `has_error()`；中断后不再解析本块；负例：回调返回 1，断言 `feed == -1`、`has_error()` 为真、后续事件未分发 |
| 中 | `retry` 被当成“只在当前事件有效” | 每个事件后清掉重连时间，客户端用默认值重连；服务端下发的退避失效。`SseEvent.retry` 可做当前快照，但不能反推 parser 状态 | 按 WHATWG 把 `_retry` 做成流级状态：只在 `retry` 字段为纯数字时更新，跨事件保留；`retry_hint()` 返回它；负例：事件 A 设 3000，事件 B 不设，断言 B 后仍为 3000 |
| 中 | `_line_len + 1 >= _max_line_bytes` 的边界 | 若 `n` 被理解为“最大内容字节数”，恰好 `n` 字节的合法行被误拒；若 `n` 是含 NUL 的容量，则该判据正确，但 API 文档没写清 | 明确契约：`max_line_bytes(n)` 的 `n` = 含结尾 NUL 的缓冲容量，内容上限 `n-1`；或改为分配 `n+1` 并判 `_line_len >= n`。负例测 `n-1`/`n`/`n+1` 三种行 |
| 中 | `_xxx` 方法实际是公开 API | 消费者可以调用/链接 `SseParser__xxx`；改名或删私有 helper 变成破坏性变更；符号面比设计大 | 私有逻辑写成 `.ct` 内 `static` 自由函数；`.h.ct` 只留 `new`/`on_event`/`feed`/`finish`/`has_error`/`error_msg`/`last_event_id`/`retry_hint`/`reset`；在 API 文档列明公开面 |
| 中 | `SseParser` 按值内嵌 `SseEvent`，而生成头不带 `#include` | 若两个类型分居两个 `.h.ct`，消费者的 `SseParser.h` 需要先看到 `SseEvent` 的完整定义；include 顺序错就编译失败 | 两个类型放同一个 `.h.ct`；或保证依赖头先被包含，并在包文档写死顺序 |
| 低 | 文件作用域 `_set_error` 使用前导 `_` + 小写 | C 标准把该形态保留给实现；换编译器/平台可能撞符号或告警 | 改名 `sse_set_error`（或 `sse_errorf`）；字段 `_x` 不受影响 |

## 4 WHATWG 语义核对

| 项 | 提案/常见写法 | 判定 | 修正 |
| --- | --- | --- | --- |
| `id` 持久与清除 | 只写“持久”，未写空值 | **漏** | `id:` 空值把 last event ID 置空；值含 NUL 时整条忽略；`last_event_id()` 返回该缓冲，跨事件保留 |
| `retry` 作用域 | “只在当前事件有效” | **错** | `retry` 更新的是**流级**重连时间，跨事件保留；只接受纯 ASCII 数字，否则忽略 |
| `data` 末尾 `\n` | “去掉末尾 `\n`” | **对一半** | 只去掉**一个** LF；多行 `data` 之间的 LF 保留；不要 `while`/`trim` |
| 空 `data` 不分发 | “空 data 不分发” | **部分错** | 没有 `data` 字段（data buffer 为空）才不分发；`data:` 会先产生 `"\n"`，trim 后为空串，仍应分发一个空 data 事件。用 `_has_data` 标记，别只看 trim 后长度 |
| 无冒号行 | “整行为字段名” | **对** | `data`（无冒号）= `data:`，空值；未知字段忽略 |
| 注释行 | 未提 | **漏** | 行首 `:` 整行忽略，即使后面还有冒号 |
| 冒号后空格 | 未提 | **漏** | 值只去掉**一个**前导空格；`data:  x` 的第一个空格去掉，第二个保留 |
| `event` 生命周期 | 未提 | **漏** | 事件类型缓冲在 dispatch 后清空；空值按 `message`；`event` 不跨事件 |
| 行结束/BOM | 未提 | **漏** | 支持 CRLF、单 CR、单 LF；流首 BOM 去掉 |
| `lastEventId` 取值点 | 未提 | **漏** | 在 dispatch 时读 last event ID 缓冲；`id` 行在空行前出现才影响本事件 |

## 5 与既有条款的冲突

| 既有条款 | 冲突点 | 处理 |
| --- | --- | --- |
| [phase40-draft.md](file:///Users/samxx/trae-ws/ct-lang/docs/design/phase40-draft.md) L1 自定义 `[]` | ct-sse 用 `char *` 手动缓冲，不需要自定义下标；若在 `SseParser` 上写 `p[0]`，L1 落地后会从 `cc` 错误变成编译期硬错 | 不依赖 L1；C 指针/数组下标保持 C 语义；不要给 parser 定义 `get`/`set` |
| [bindings-and-patterns.md](file:///Users/samxx/trae-ws/ct-lang/docs/bindings-and-patterns.md) §5 `own` | `new()` 是工厂返回，不能写 `own SseParser *p = SseParser::new()`；`own` 只认裸 `malloc`/`calloc`，加转型还会破坏识别 | 用 `delete p;`；`new()` 内部 `calloc`；不要给返回值加 cast 后交给 `own` |
| 同上 §3 函数指针 | `on_event` 若是函数指针类型，消费者传 CT 闭包字面量不是普通 C 回调（SH-67） | API 只收具名函数/函数指针；文档给 `static int cb(SseEvent *ev, void *ud)` 例子 |
| 同上 §2 `.m.ct` 变参 | `_set_error` 是 CT 自定义变参函数，不是 C 绑定；放进 `impl` 会触发“a struct method cannot be variadic” | 放在 `.ct` 的自由 `static` 函数；`.m.ct` 的变参尾规则不适用 |
| Phase 36 Drop 语义 | 显式 `impl Drop` 不生成字段递归 glue；`_current` 不会被自动清理 | 在 `drop` 里只释放 parser 自己的三块缓冲；`SseEvent` 不加 `use Drop` |
| `pub struct` 方法导出 | `_xxx` 会进入生成头；没有方法级 `pub`/私有修饰符 | 私有 helper 改 `static` 自由函数；公开面在文档固定 |

## 6 阶段切分意见（只给意见，不出卡）

> 本会话只拿到 API 与 S1–S7 编号，未见逐条阶段定义；以下按编号顺序的常见职责给意见，
> 若原提案定义不同，以原定义为准。

- **S1（类型/错误骨架）保留**；把 `has_error`/`error_msg` 提前到 S1，否则后续阶段无法写负例。
- **S2（行读取）保留，但必须带上行上限、跨 `feed` 半行、CR/LF/CRLF 三组负例**；这些边界不能留到 S7。
- **S3（字段解析）拆到 T 级**：`id`、`retry`、`data`、`event` 各自一个 T，每个 T 一条 WHATWG 对照负例；不要合成一个“字段解析”大阶段。
- **S4（分发/回调）拆成两个 T**：一个只管事件组装与空 data 规则，一个只管回调返回值/中断契约；两者混在一起时“返回次数还是 -1”永远测不清。
- **S5（reset/limits）合并进 S3/S4**；`reset` 与行上限是边界，不是收尾。
- **S6（公开 API/错误文本）合并进 S1**；API 面一旦定了，`_xxx` 的公开问题就固定了。
- **S7（测试/文档）不要作为独立实现阶段**；测试随每个 T 走，S7 只留 WHATWG 对照表、示例与 `sse_event_copy` 的用法。
- **新增 S0：契约冻结**（`feed` 返回值、事件字段生命周期、`max_line_bytes` 的 `n` 含义、回调中断后是否继续解析）。S0 不写实现，只写一页契约与负例清单。

## 7 是否引入新的语言能力需求

**不引入。** 现有能力足够：变参自由函数、`pub struct`/`pub typedef`、`self->`、`static` 方法、
显式 `Drop`、`malloc/calloc/free`、C 头直用。

只有三种“想引入”的诱因，均建议拒绝：

1. **借用检查**（让编译器保证 `SseEvent` 字段不逃逸）——这是借用检查器，不是本包需求；用 copy API + 负例测试兜底。
2. **方法级私有**（让 `_xxx` 真私有）——CT 没有方法可见性；用 `.ct` 内 `static` 自由函数替代，不扩语言。
3. **工厂返回值可 `own`**——`delete` 已覆盖；改 `own` 规则会碰 AutoDrop 配对（phase40 风险 R40-3 同类），不做。

`custom []`（phase40 L1）也不是本包需求；ct-sse 继续用 `char *` + 显式索引即可。

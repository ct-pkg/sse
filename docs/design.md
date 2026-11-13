# ct-sse 设计待决项

> 状态：分析阶段，未立项。以下四条来自 [分析结论](analysis.md) 第 1 节，立项前必须逐条定稿。
> 每条给出：现状 / 待定 / 影响。

| # | 议题 | 现状 | 待定 | 影响 |
| --- | --- | --- | --- | --- |
| 1 | `_set_error` 不能用变参方法 | 提案把 `int _set_error(char *fmt, ...)` 放在 `impl SseParser`；CT 拒绝 struct 方法带 `...`（`Parser.h.ct:3153-3155`） | 改成 `.ct` 内 `static int sse_set_error(SseParser *p, char *fmt, ...)`，或拆成 `vsnprintf` 核心 + 固定参数包装 | 错误缓冲的归属、`vsnprintf` 的截断策略、错误 API 是否暴露 |
| 2 | `_xxx` 前缀不是私有语义 | 同一 `.h.ct` 内 `pub struct` 的 impl 方法全部进生成头，`_xxx` 只是命名约定（`Emitter.h.ct:3328-3353`） | 接受公开面并在文档列出，或把 `_ensure` / `_push_char` / `_push_str` / `_process_line` / `_handle_field` / `_dispatch_event` 改成 `.ct` 内 `static` 自由函数 | 符号面大小、消费者可链接到的 API、后续改名是否破坏兼容 |
| 3 | `retry` 是流级持久状态 | 提案 5.6 在 dispatch 后 `_retry = 0`，注释称“retry 只在当前事件有效”；WHATWG 的 reconnection time 是流级，`retry` 字段更新后跨事件保留 | `SseEvent.retry` 只做当前快照，`SseParser._retry` 持久；`retry_hint()` 返回持久值；`reset()` 是否清 `_retry` 需定为“新流则清” | 重连退避行为、事件字段与 parser 状态的一致性、跨事件测试 |
| 4 | `feed` 返回值契约二选一 | `feed` 注释“返回回调次数；致命错误返回 -1”，但 `_dispatch_event` 把回调非 0 转成 `_set_error("callback aborted")` 返回 -1，中断与计数语义冲突 | A）成功 `>= 0` 次数、任何错误（含回调中断）`-1`，中断后停止解析；B）始终返回次数，错误只看 `has_error()`，中断后是否继续另定 | ct-http chunk 回调如何决定中断传输、测试断言、对外文档契约 |

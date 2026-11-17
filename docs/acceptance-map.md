# 验收映射（ACC-* ↔ R-* ↔ 证据）

> G2 的机器可读映射。`ACC-*` 与 `docs/requirements.md` 的 `R-*` 一一对应；
> 证据列至少指向 `S14` 覆盖表或一个存在的夹具。新增/删除需求时必须同步本表。

| ACC | 需求 | 要什么（摘要） | 判据 | 证据 |
| --- | --- | --- | --- | --- |
| ACC-A-01 | R-A-01 | 跨 `feed` 保留半行；分片不改变事件序列 | `"data: hel"`+`"lo\n\n"` 与整块/逐字节输入产生相同事件；回调 1 次、data=`hello` | `docs/reviews/S14-coverage.md` |
| ACC-A-02 | R-A-02 | 支持 CRLF / 单 CR / 单 LF；CRLF 可跨分片；CR 后非 LF 时 CR 即行结束 | 三种行结束各出 1 事件；`data: a\r`+`\n\r\n` 只出 1 次 | `docs/reviews/S14-coverage.md` + `test/fixtures/s4_chunk.ct` |
| ACC-A-03 | R-A-03 | 行首 `:` 整行是注释，即使行内还有冒号 | `:data: x\n\n` 出 0 事件；不改变任何字段状态 | `docs/reviews/S14-coverage.md` + `test/fixtures/s2_syntax.ct` |
| ACC-A-04 | R-A-04 | 按**第一个**冒号切分；值前只去**一个**空格；无冒号=空值；未知字段忽略；字段名大小写敏感 | `data:  x`→`" x"`；`data: a:b:c`→全值；`data`→空值；`Data: x` 0 事件 | `docs/reviews/S14-coverage.md` + `test/fixtures/s2_syntax.ct` |
| ACC-A-05 | R-A-05 | `data` 每次追加「值 + LF」；分发时只去**一个**末尾 LF | `"data: a\ndata:\n\n"`→`"a\n"`；YHOO/+2/10 用例 `len=10` | `docs/reviews/S14-coverage.md` + `test/fixtures/s2_basic.ct` + `test/fixtures/s2_syntax.ct` |
| ACC-A-06 | R-A-06 | 以「本块是否出现过 data 字段」判定是否分发；`data:` 分发空 data 事件 | `data:\n\n`→1 次、`data_len=0`；无 data 的块 0 次 | `docs/reviews/S14-coverage.md` + `test/fixtures/s2_basic.ct` |
| ACC-A-07 | R-A-07 | `event` 缺省/空值为 `message`；dispatch 后清空，无 data 的块也清空 | ping 后的事件回落 message；`event: ghost\n\n` 后的事件为 message | `docs/reviews/S14-coverage.md` + `test/fixtures/s3_fields.ct` |
| ACC-A-08 | R-A-08 | `id` 跨事件持久；空值清除；含 NUL 整条忽略；取值为 dispatch 时刻 | 持久、清除、NUL 忽略各有断言；同一块 data 后的 `id` 仍作用于本事件 | `docs/reviews/S14-coverage.md` + `test/fixtures/s3_fields.ct` + `test/fixtures/s3_state.ct` |
| ACC-A-09 | R-A-09 | `retry` 只接受非空纯 ASCII 数字；溢出与非法忽略；`retry: 0` 合法；跨事件与 `reset` 保持 | `has_retry()` 0/1；`retry: 0`→1/0；`2147483648` 保留前值；`007`→7 | `docs/reviews/S14-coverage.md` + `test/fixtures/s3_retry_zero.ct` + `test/fixtures/s3_state.ct` |
| ACC-A-10 | R-A-10 | 空行是事件边界；无 data 的块不分发，但 event 缓冲按规范清空 | 连续空行 0 次；两个 data 块 2 次且有序 | `docs/reviews/S14-coverage.md` + `test/fixtures/s2_basic.ct` + `test/fixtures/s3_fields.ct` |
| ACC-A-11 | R-A-11 | 流首（含 `reset` 后）一个 `EF BB BF` 忽略；非 BOM 前缀按普通字节回放；**流中**再出现 BOM 字节不剥 | 整块/跨 3 分片均只剥一次；`d`+`ata: h` 回放；中段 BOM 行 0 事件 | `docs/reviews/S14-coverage.md` + `test/fixtures/s4_bom_edge.ct` + `test/fixtures/s4_chunk.ct` |
| ACC-A-12 | R-A-12 | 到达 EOF 时丢弃 pending 半行与未分发 data，不分发流末不完整事件 | `data: pending`+`finish`→0 事件；`finish` 后 `feed`=-1 | `docs/reviews/S14-coverage.md` + `test/fixtures/s6_finish_eof.ct` |
| ACC-B-01 | R-B-01 | 回调可读 `event`/`data`/`data_len`/`id`/`retry`；data 可含 NUL | `data_len` 覆盖全部字节（含 NUL）；三个字段判定与 W6–W8 一致 | `docs/reviews/S14-coverage.md` |
| ACC-B-02 | R-B-02 | 每个分发事件恰好一次回调；`ud` 原样回传 | 回调次数与 `ud` 可断言；未注册回调时静默丢弃（`feed`≥0、无错误） | `docs/reviews/S14-coverage.md` |
| ACC-B-03 | R-B-03 | 回调返回非 0 是唯一提前终止：`feed`=-1、码 3、本块剩余不再解析 | 中断前已分发事件照常计数；后续字节不分发 | `docs/reviews/S14-coverage.md` + `test/fixtures/s5_abort.ct` |
| ACC-B-04 | R-B-04 | 事件视图是借用：只在回调内有效，且不晚于下一次 `feed`/`finish`/`reset`/销毁 | `delete` 后读视图在 ASan 下报 heap-use-after-free | `docs/reviews/S14-coverage.md` + `test/fixtures/s6_borrow_uaf.ct` |
| ACC-B-05 | R-B-05 | 跨回调保留必须显式深拷贝；副本独立于 parser | 副本在后续 feed 与 `delete` 后内容不变；OOM 返回 0 | `docs/reviews/S14-coverage.md` + `test/fixtures/s6_copy.ct` + `test/fixtures/s9_oom.ct` |
| ACC-C-01 | R-C-01 | 构造返回可用实例；分配失败返回 0；销毁释放全部内部缓冲 | 构造/销毁可断言；销毁后计数器归零 | `docs/reviews/S14-coverage.md` |
| ACC-C-02 | R-C-02 | 所有分配失败路径返回 -1、置码 2、文本 `out of memory`；失败后 `reset` 可恢复 | parser/行缓冲/data 缓冲/copy 四处注入各有断言 | `docs/reviews/S14-coverage.md` + `test/fixtures/s9_oom.ct` |
| ACC-C-03 | R-C-03 | 所有分配与释放可被测试在运行期替换；测试钩子不进生成头、不进公开 ABI；生产构建无桩 | `grep` 生成头无钩子，`--lib` 归档无钩子符号；失败次数由运行期变量控制 | `docs/reviews/S14-coverage.md` |
| ACC-C-04 | R-C-04 | 提供分配/释放计数能力，用于证明整块缓冲不漏释放 | 整块/逐字节/伪随机三种切法 `allocs==frees && live==0`；野指针/越界不在其能力内 | `docs/reviews/S14-coverage.md` + `test/fixtures/s9_alloc_count.ct` |
| ACC-C-05 | R-C-05 | 单行有可配置的内容字节上限；默认 65536；恰好 `n` 合法、`n+1` 报错 | 以 `n=4096` 写死正例/反例；错误文本含当前上限 | `docs/reviews/S14-coverage.md` + `test/fixtures/s5_limits.ct` |
| ACC-C-06 | R-C-06 | `reset` 清行/data/event/`has_data`/`saw_cr`/BOM/错误/finish；保留 lastEventId、retry、回调、上限 | reset 后半行不污染下一事件；id/retry/回调/上限保留 | `docs/reviews/S14-coverage.md` + `test/fixtures/s3_retry_zero.ct` + `test/fixtures/s3_state.ct` |
| ACC-C-07 | R-C-07 | `finish()` 只做 EOF 清理；之后 `feed`=-1，直到 `reset`；保留 id/retry | 计数快照前后不增、销毁后归零；行为上不吐旧数据、不生效半行 | `docs/reviews/S14-coverage.md` + `test/fixtures/s3_state.ct` + `test/fixtures/s9_finish_clean.ct` |
| ACC-D-01 | R-D-01 | 成功 `feed` 返回本次回调次数；任何致命返回 -1 | 致命后终止态；`finish`/再次 `feed` 幂等 -1，`reset` 是唯一出口 | `docs/reviews/S14-coverage.md` + `test/fixtures/s5_limits.ct` |
| ACC-D-02 | R-D-02 | 错误码固定：0 无、1 协议/上限、2 OOM、3 回调中止、4 重入、5 已 finish | 每个码有直接断言；文本精确匹配 | `docs/reviews/S14-coverage.md` + `test/fixtures/s9_error_codes.ct` |
| ACC-D-03 | R-D-03 | 协议非致命（未知字段/非法 retry/注释/NUL id）不置错 | 这些输入后 `has_error()==0`、`error_msg()==NULL` | `docs/reviews/S14-coverage.md` + `test/fixtures/s2_syntax.ct` + `test/fixtures/s3_fields.ct` |
| ACC-D-04 | R-D-04 | 可查询持久 lastEventId 与 retry 建议：`last_event_id()`、`has_retry()`、`retry_hint()` | 无 id 返回 0；`has_retry()` 为 0 时 `retry_hint()` 不构成契约，调用方先判 | `docs/reviews/S14-coverage.md` |
| ACC-D-05 | R-D-05 | 回调执行期间禁止对同一 parser 调用 `feed`/`finish`/`reset`/销毁/`on_event`/`max_line_bytes` | 六类调用均返回 -1 或只置错，码 4，文案 `reentrant call is not allowed`；parser 仍可用 | `docs/reviews/S14-coverage.md` + `test/fixtures/s10_reentrant.ct` + `test/fixtures/s10_reentrant_state.ct` |
| ACC-D-06 | R-D-06 | 回调返回非 0 终止后，`reset` 可复用 parser | 终止后 reset+feed 正常出事件 | `docs/reviews/S14-coverage.md` + `test/fixtures/s10_reentrant.ct` + `test/fixtures/s5_abort.ct` |
| ACC-E-01 | R-E-01 | 注册表方法返回宿主自身，调用方可一行落变量；`make` 返回构造对象 | `SseRegistry reg = base.reg(...)` 可编译运行；`make` 返回实例或 0 | `docs/reviews/S14-coverage.md` + `test/fixtures/s8_registry.ct` |
| ACC-E-02 | R-E-02 | 缺失键返回 0 + `err=1`；同名键首条生效、不覆盖 + `err=2`；满 8 条 + `err=3`；`make` 命中 `err=0` | 四种错误码各有直接断言；条目数不变 | `docs/reviews/S14-coverage.md` + `test/fixtures/s8_registry.ct` |
| ACC-E-03 | R-E-03 | `name` 是借用，必须是字面量或静态存储；方法结果不能作下一跳接收者 | README 示例逐句落变量；契约写清借用 | `docs/reviews/S14-coverage.md` |
| ACC-F-01 | R-F-01 | 公开 API 面冻结且可枚举；清单外不承诺 | 生成头导出符号与清单完全一致（不多不少） | `docs/reviews/S14-coverage.md` |
| ACC-F-02 | R-F-02 | 构建零警告（`-Wall -Wextra -Werror`，ct 自身也不得 warning） | `-Werror` 将警告升级为错误，构建退出码非 0 即失败（PH-12；不再匹配 `warning:` 文本） | `docs/reviews/S14-coverage.md` |
| ACC-F-03 | R-F-03 | 真实 ct-http 发布版能驱动 `feed`；集成门禁独立于单包门禁 | BOM 分片、data 跨 chunk、多行 data、id/retry 持久、空 id、空行、EOF 均有断言 | `docs/reviews/S14-coverage.md` |
| ACC-F-04 | R-F-04 | 包不反向依赖下游；`vendor/` 只用于集成、不进发布产物 | `sse/` 无 `import`；发布产物只有 `sse/` 与 `ct.pkg` | `docs/reviews/S14-coverage.md` |
| ACC-F-05 | R-F-05 | 契约细则要么有夹具，要么在契约标「无独立用例」并给理由 | 覆盖表逐条有状态；无独立用例 9 条有理由 | `docs/reviews/S14-coverage.md` |

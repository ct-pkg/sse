# ct-sse 需求定稿

> 定位：五层产物中的**第三层**。只写「要什么、不要什么、边界在哪」，不含实现方式、进度与排期。
> 依据：[研判评估](reviews/evaluation.md)（每条需求后面的 `依据` 列可追到具体裁定与实测）。
> 被推翻的写法不再出现在本文；逐条对照见 [evaluation §4](reviews/evaluation.md)。

## 1 一句话需求

把可能被任意分片的 WHATWG SSE 字节流，增量解析成事件回调；协议层的非致命情况静默忽略，
资源与回调错误可通过错误码与文本查询；本包只做解析。

## 2 系统边界与依赖方向

| 项 | 口径 | 依据 |
| --- | --- | --- |
| 依赖方向 | `ct-llm-sse → ct-sse → ct-http`（箭头读作「依赖」）。`ct-http` 更底层，不得依赖 `ct-sse`；`ct-sse` 不得依赖 `ct-llm-sse` | 第 16 题、[S16](reviews/S16-dependency-direction.md) |
| 上游输入 | 任意分片的字节块 `feed(chunk, len)`，不保证按行/按事件对齐 | B-1、B-2 |
| 下游输出 | 同步事件回调 `SseEventCb(SseEvent *, void *)`；回调在调用 `feed` 的线程上触发 | B-2、C-1 |
| 不属于本包 | HTTP 传输与连接管理、LLM 协议语义、重连策略、事件路由/多订阅 | B-12 |
| 并发 | 同一个 parser 不得被多线程同时 `feed`/`finish`/`reset`/销毁；包内无锁 | 第 8 题、S0 卡 C-1 |

## 3 需求条目

### 3.1 A 组：协议解析

| 编号 | 要什么 | 不要什么 | 边界/判据 | 依据 |
| --- | --- | --- | --- | --- |
| R-A-01 | 跨 `feed` 保留半行；分片不改变事件序列 | 不做网络读取与分片调度 | `"data: hel"`+`"lo\n\n"` 与整块/逐字节输入产生相同事件；回调 1 次、data=`hello` | B-1、W1 |
| R-A-02 | 支持 CRLF / 单 CR / 单 LF；CRLF 可跨分片；CR 后非 LF 时 CR 即行结束 | 不做字符编码转换 | 三种行结束各出 1 事件；`data: a\r`+`\n\r\n` 只出 1 次 | W1；`s4_chunk` |
| R-A-03 | 行首 `:` 整行是注释，即使行内还有冒号 | 不保留注释、不回调注释 | `:data: x\n\n` 出 0 事件；不改变任何字段状态 | W2；`s2_syntax` |
| R-A-04 | 按**第一个**冒号切分；值前只去**一个**空格；无冒号=空值；未知字段忽略；字段名大小写敏感 | 不做字段名规范化/别名 | `data:  x`→`" x"`；`data: a:b:c`→全值；`data`→空值；`Data: x` 0 事件 | W3；`s2_syntax` |
| R-A-05 | `data` 每次追加「值 + LF」；分发时只去**一个**末尾 LF | 不做 while-trim、不裁其他空白 | `"data: a\ndata:\n\n"`→`"a\n"`；YHOO/+2/10 用例 `len=10` | W4；`s2_basic`、`s2_syntax` |
| R-A-06 | 以「本块是否出现过 data 字段」判定是否分发；`data:` 分发空 data 事件 | 不把空 data 当错误；不合并空事件 | `data:\n\n`→1 次、`data_len=0`；无 data 的块 0 次 | W5；`s2_basic` |
| R-A-07 | `event` 缺省/空值为 `message`；dispatch 后清空，无 data 的块也清空 | 不做事件类型路由/订阅 | ping 后的事件回落 message；`event: ghost\n\n` 后的事件为 message | W6；`s3_fields` |
| R-A-08 | `id` 跨事件持久；空值清除；含 NUL 整条忽略；取值为 dispatch 时刻 | 不生成 `Last-Event-ID` 请求头 | 持久、清除、NUL 忽略各有断言；同一块 data 后的 `id` 仍作用于本事件 | W7；`s3_fields`、`s3_state` |
| R-A-09 | `retry` 只接受非空纯 ASCII 数字；溢出与非法忽略；`retry: 0` 合法；跨事件与 `reset` 保持 | 不实现退避算法、不在本包内重连 | `has_retry()` 0/1；`retry: 0`→1/0；`2147483648` 保留前值；`007`→7 | 第 4 题、W8；`s3_retry_zero`、`s3_state` |
| R-A-10 | 空行是事件边界；无 data 的块不分发，但 event 缓冲按规范清空 | 不排队延迟分发 | 连续空行 0 次；两个 data 块 2 次且有序 | W5/W6；`s2_basic`、`s3_fields` |
| R-A-11 | 流首（含 `reset` 后）一个 `EF BB BF` 忽略；非 BOM 前缀按普通字节回放；**流中**再出现 BOM 字节不剥 | 不做编码转换 | 整块/跨 3 分片均只剥一次；`d`+`ata: h` 回放；中段 BOM 行 0 事件 | W9；`s4_chunk`、`s4_bom_edge` |
| R-A-12 | 到达 EOF 时丢弃 pending 半行与未分发 data，不分发流末不完整事件 | 不隐式 `reset`/销毁 | `data: pending`+`finish`→0 事件；`finish` 后 `feed`=-1 | W10、第 12 题；`s6_finish_eof` |

### 3.2 B 组：事件暴露与所有权

| 编号 | 要什么 | 不要什么 | 边界/判据 | 依据 |
| --- | --- | --- | --- | --- |
| R-B-01 | 回调可读 `event`/`data`/`data_len`/`id`/`retry`；data 可含 NUL | 不让 `SseEvent` 拥有内存 | `data_len` 覆盖全部字节（含 NUL）；三个字段判定与 W6–W8 一致 | B-3、B-11 |
| R-B-02 | 每个分发事件恰好一次回调；`ud` 原样回传 | 不支持多订阅、闭包字面量、路由 | 回调次数与 `ud` 可断言；未注册回调时静默丢弃（`feed`≥0、无错误） | B-3 |
| R-B-03 | 回调返回非 0 是唯一提前终止：`feed`=-1、码 3、本块剩余不再解析 | 不定义栈展开/异常 | 中断前已分发事件照常计数；后续字节不分发 | B-2；`s5_abort` |
| R-B-04 | 事件视图是借用：只在回调内有效，且不晚于下一次 `feed`/`finish`/`reset`/销毁 | 不做借用检查 | `delete` 后读视图在 ASan 下报 heap-use-after-free | B-3；`s6_borrow_uaf` |
| R-B-05 | 跨回调保留必须显式深拷贝；副本独立于 parser | 不提供引用计数/GC | 副本在后续 feed 与 `delete` 后内容不变；OOM 返回 0 | B-11；`s6_copy`、`s9_oom` |

### 3.3 C 组：生命周期、内存与配置

| 编号 | 要什么 | 不要什么 | 边界/判据 | 依据 |
| --- | --- | --- | --- | --- |
| R-C-01 | 构造返回可用实例；分配失败返回 0；销毁释放全部内部缓冲 | 不用 `own`、不做引用计数 | 构造/销毁可断言；销毁后计数器归零 | B-3、A-1 |
| R-C-02 | 所有分配失败路径返回 -1、置码 2、文本 `out of memory`；失败后 `reset` 可恢复 | 不把 OOM 折成协议错误 | parser/行缓冲/data 缓冲/copy 四处注入各有断言 | 第 6 题；`s9_oom` |
| R-C-03 | 所有分配与释放可被测试在运行期替换；测试钩子不进生成头、不进公开 ABI；生产构建无桩 | 不用编译期开关；不把测试桩带进生产路径 | `grep` 生成头无钩子，`--lib` 归档无钩子符号；失败次数由运行期变量控制 | 第 6 题；S9 §1 |
| R-C-04 | 提供分配/释放计数能力，用于证明整块缓冲不漏释放 | 不把计数器说成「泄漏已验」 | 整块/逐字节/伪随机三种切法 `allocs==frees && live==0`；野指针/越界不在其能力内 | 第 7 题；`s9_alloc_count` |
| R-C-05 | 单行有可配置的内容字节上限；默认 65536；恰好 `n` 合法、`n+1` 报错 | 不限事件 data 总量；`n<=0` 不生效且保留旧值 | 以 `n=4096` 写死正例/反例；错误文本含当前上限 | 第 5 题、B-9；`s5_limits` |
| R-C-06 | `reset` 清行/data/event/`has_data`/`saw_cr`/BOM/错误/finish；保留 lastEventId、retry、回调、上限 | 不释放缓冲容量、不重置配置 | reset 后半行不污染下一事件；id/retry/回调/上限保留 | B-4、F-3；`s3_state`、`s3_retry_zero` |
| R-C-07 | `finish()` 只做 EOF 清理；之后 `feed`=-1，直到 `reset`；保留 id/retry | 不加只读视察接口 | 计数快照前后不增、销毁后归零；行为上不吐旧数据、不生效半行 | 第 12 题、A-2；`s9_finish_clean`、`s3_state` |

### 3.4 D 组：错误、状态与重入

| 编号 | 要什么 | 不要什么 | 边界/判据 | 依据 |
| --- | --- | --- | --- | --- |
| R-D-01 | 成功 `feed` 返回本次回调次数；任何致命返回 -1 | 不把「次数」与「错误」混用 | 致命后终止态；`finish`/再次 `feed` 幂等 -1，`reset` 是唯一出口 | B-2；`s5_limits` |
| R-D-02 | 错误码固定：0 无、1 协议/上限、2 OOM、3 回调中止、4 重入、5 已 finish | 不做错误分类扩展 | 每个码有直接断言；文本精确匹配 | B-8、第 15 题；`s9_error_codes` |
| R-D-03 | 协议非致命（未知字段/非法 retry/注释/NUL id）不置错 | 不把忽略项写成错误 | 这些输入后 `has_error()==0`、`error_msg()==NULL` | B-1；`s3_fields`、`s2_syntax` |
| R-D-04 | 可查询持久 lastEventId 与 retry 建议：`last_event_id()`、`has_retry()`、`retry_hint()` | 不返回副本、不生成请求头 | 无 id 返回 0；`has_retry()` 为 0 时 `retry_hint()` 不构成契约，调用方先判 | 第 4 题；S0 卡 R-2 |
| R-D-05 | 回调执行期间禁止对同一 parser 调用 `feed`/`finish`/`reset`/销毁/`on_event`/`max_line_bytes` | 不做重入支持（半解析状态被外部改写需复制或排队，与纯解析器定位不符） | 六类调用均返回 -1 或只置错，码 4，文案 `reentrant call is not allowed`；parser 仍可用 | 第 15 题、C-2；`s10_reentrant`、`s10_reentrant_state` |
| R-D-06 | 回调返回非 0 终止后，`reset` 可复用 parser | 禁止重入不等于禁止终止后复用 | 终止后 reset+feed 正常出事件 | 第 15 题；`s5_abort`、`s10_reentrant` |

### 3.5 E 组：注册表

| 编号 | 要什么 | 不要什么 | 边界/判据 | 依据 |
| --- | --- | --- | --- | --- |
| R-E-01 | 注册表方法返回宿主自身，调用方可一行落变量；`make` 返回构造对象 | 不用静态工厂；不用内置类型作宿主 | `SseRegistry reg = base.reg(...)` 可编译运行；`make` 返回实例或 0 | 第 3 题；`s8_registry` |
| R-E-02 | 缺失键返回 0 + `err=1`；同名键首条生效、不覆盖 + `err=2`；满 8 条 + `err=3`；`make` 命中 `err=0` | 不静默覆盖、不无限扩容 | 四种错误码各有直接断言；条目数不变 | 第 3 题；`s8_registry` |
| R-E-03 | `name` 是借用，必须是字面量或静态存储；方法结果不能作下一跳接收者 | 不复制 name、不支持链式 | README 示例逐句落变量；契约写清借用 | 第 3 题；S0 卡 R-1 |

### 3.6 F 组：工程与交付边界

| 编号 | 要什么 | 不要什么 | 边界/判据 | 依据 |
| --- | --- | --- | --- | --- |
| R-F-01 | 公开 API 面冻结且可枚举；清单外不承诺 | 不扩方法级可见性、不申请语言改动 | 生成头导出符号与清单完全一致（不多不少） | B-10；S0 卡 §3 |
| R-F-02 | 构建零警告（`-Wall -Wextra -Werror`，ct 自身也不得 warning） | 不放宽警告门禁 | `-Werror` 将警告升级为错误，构建退出码非 0 即失败（PH-12；不再匹配 `warning:` 文本） | 第 11 题；`test/run.sh` |
| R-F-03 | 真实 ct-http 发布版能驱动 `feed`；集成门禁独立于单包门禁 | 不改 ct-http；不把集成依赖塞进单包门禁 | BOM 分片、data 跨 chunk、多行 data、id/retry 持久、空 id、空行、EOF 均有断言 | 第 13 题；`test/integration.sh` |
| R-F-04 | 包不反向依赖下游；`vendor/` 只用于集成、不进发布产物 | 不把测试替身写成产品依赖 | `sse/` 无 `import`；发布产物只有 `sse/` 与 `ct.pkg` | 第 16 题；[S16](reviews/S16-dependency-direction.md) |
| R-F-05 | 契约细则要么有夹具，要么在契约标「无独立用例」并给理由 | 不用只断言常量的用例凑覆盖率 | 覆盖表逐条有状态；无独立用例 9 条有理由 | 第 14 题；[S14](reviews/S14-coverage.md)、S0 卡 §9 |

## 4 明确不做（非目标）

1. 不做 HTTP 传输、连接管理、chunk 读取（`ct-http` 负责）。
2. 不做 LLM 协议语义解析（`ct-llm-sse` 负责）。
3. 不做重连策略、退避算法、事件路由/多订阅。
4. 不做字符编码转换（BOM 除外）。
5. 不做线程安全；不做借用检查；不做方法级私有扩展；不请求 `Vec<T>.data()`。
6. 不提供只读视察/调试接口；不为测试在产品里开口子。
7. 不支持回调内重入；不做链式调用糖；不改 `ct-http`。

## 5 依据索引

| 主题 | 评估/证据 |
| --- | --- |
| 十六问逐条 | [evaluation.md](reviews/evaluation.md) §2 |
| 语言事实与 battle | [S0-facts](reviews/S0-facts.md)、[S0-battle](reviews/S0-battle.md) |
| 构造形态 | [S0-constructor-shapes](reviews/S0-constructor-shapes.md) |
| 内置类型宿主与注册表 | [S8-int-host](reviews/S8-int-host.md) |
| 分配器、OOM、计数、四类记账、finish 可观测性 | [S9-allocator](reviews/S9-allocator.md) |
| ct-http 真实对接 | [S13](reviews/S13-http-integration.md) |
| 契约细则覆盖 | [S14](reviews/S14-coverage.md) |
| 依赖方向 | [S16](reviews/S16-dependency-direction.md) |

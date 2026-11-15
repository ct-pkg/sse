# 研判评估总表

> 日期：2026-11-15。语言基线：CT v0.53.0。
> 定位：五层产物中的**第二层**。只回答「提案的哪条成立/不成立、依据是什么」，
> 不写需求口径（那是 [需求定稿](../requirements.md)），不排期（那是 [roadmap](../planning/roadmap.md)）。

## 0 五层产物位置

| 层 | 产物 | 状态 |
| --- | --- | --- |
| 1 提案 | [docs/proposal.md](../proposal.md) | **原文留档，正文未删改**（文件头已声明） |
| 2 研判评估 | 本文 + [S0-facts](S0-facts.md)、[S0-battle](S0-battle.md)、[S0-constructor-shapes](S0-constructor-shapes.md)、[S8-int-host](S8-int-host.md)、[S9-allocator](S9-allocator.md)、[S13](S13-http-integration.md)、[S14](S14-coverage.md)、[S16](S16-dependency-direction.md) | 本文为索引；分报告保留原始探针/夹具输出 |
| 3 需求定稿 | [docs/requirements.md](../requirements.md) | 已按裁定重写，只写要什么/不要什么/边界 |
| 4 路线图 | [docs/planning/roadmap.md](../planning/roadmap.md) | 片序、依赖、验收判据、版本落点 |
| 5 phase 卡 | [docs/phases/PH-01…PH-14](../phases/) | 已完成片回溯补卡，未开工片前瞻卡 |

## 1 提案处置

提案 **不能按原文立项**，但原文保留。原因与逐条改后口径见 §3；被推翻的写法见 §4。
提案里的 S0–S7 分期被判「不可独立验收」，实际交付按能力片切分，差异见 roadmap §5。

## 2 十六个问题：结论与依据

> 编号沿用本轮评审的问题序号。每条必须有可追的实测或裁定；没有留档的编号如实登记，
> 不代拟结论。

| # | 主题 | 结论 | 依据（可追） |
| --- | --- | --- | --- |
| 1 | CT v0.53.0 语言能力与提案事实核对 | 提案 13 条中 3 条成立、5 条有条件成立、5 条不成立；10 项语言探针有原始输出 | [S0-facts](S0-facts.md) §1；[S0-battle](S0-battle.md) §1–§2 |
| 2 | 静态固有工厂不可用后的构造形态 | `SseParser::new()` 在带 namespace 单元不可用；两种替代形态实测可用但均不优于自由函数，裁定保留 `sse_parser_new()` | [S0-facts](S0-facts.md) §1.4/§1.5；[S0-battle](S0-battle.md) B-5；[S0-constructor-shapes](S0-constructor-shapes.md) |
| 3 | 注册表形态与内置类型宿主 | `impl int` 不被接受；`map trait for type int` 可挂方法但不携带状态；注册表用 struct 宿主，`reg`/`init` 按值返回宿主 | [S8-int-host](S8-int-host.md)；`s8_registry` |
| 4 | `retry` 查询拆分 | 拆为 `has_retry()` + `retry_hint()`；`retry: 0` 是合法已设置值，跨事件与 `reset` 保持 | [S0-battle](S0-battle.md) B-6；S0 卡 R-2；`s3_retry_zero` |
| 5 | 行上限的 `n` 语义 | `n` 是**内容字节**上限，恰好 `n` 合法、`n+1` 报错；判据以 `n=4096` 写死 | S0 卡 E-12；`s5_limits` |
| 6 | 可注入分配器 | 所有分配/释放收口到两个内部函数指针；钩子不进生成头、不进公开 ABI；失败次数用运行期变量 | [S9-allocator](S9-allocator.md) §1、§3；`s9_oom` |
| 7 | 分配/释放计数 | 整块、逐字节、固定种子伪随机三种切法均 `allocs==frees && live==0`；只证明整块缓冲漏释放 | [S9-allocator](S9-allocator.md) §4；`s9_alloc_count` |
| 8 | 四类记账 | 退出可达内存、真实网络分片为环境缺口；`ct`/`ct-ast` 等价性登记且不计通过数；并发写成契约 | [S9-allocator](S9-allocator.md) §5 |
| 9 | **未留档** | 本仓库没有第 9 题的裁定原文或实测记录；不代拟 | —（缺口，见 §5） |
| 10 | **未留档** | 本仓库没有第 10 题的裁定原文或实测记录；不代拟 | —（缺口，见 §5） |
| 11 | 门禁读文本的临时做法 | `test/run.sh` 用 `grep 'warning:'` 判警告；**标注为临时**，待结构化诊断能力落地后按级别判断 | [S0-closeout](S0-closeout.md) D-6；[roadmap](../planning/roadmap.md) PH-12 |
| 12 | `finish()` 之后的可观测性 | **不加只读视察接口**；只用分配计数快照 + 行为断言；块内残留长度登记为不可观测 | [S9-allocator](S9-allocator.md) §6；S0 卡 A-2；`s9_finish_clean` |
| 13 | ct-http 真实对接 | 真实发布版链路跑通；回调签名/所有权/终止语义吻合；`-I vendor/http` 是包根绕法 | [S13](S13-http-integration.md)；I-1 |
| 14 | 契约细则的夹具覆盖 | 新增 5 个夹具 + 补强 1 个；9 条无独立用例项在契约 §9 标注理由 | [S14](S14-coverage.md) |
| 15 | 回调内重入 | 禁止；生产构建同样检查；错误码 4；唯一提前终止是回调返回非 0（码 3）；终止后 `reset` 可复用 | S0 卡 C-2；`s10_reentrant`、`s10_reentrant_state` |
| 16 | 依赖方向 | `ct-llm-sse → ct-sse → ct-http`（箭头=依赖）；ct-http 无 SSE 语义；不许反向 | [S16](S16-dependency-direction.md) |

## 3 提案条目 → 裁定 → 实测

> 「提案第 X 条不成立」都在这里给出对应关系；逐字裁定在 S0-battle，原始探针在 S0-facts。

| 提案条目 | 裁定 | 改后口径 | 实测/裁定依据 |
| --- | --- | --- | --- |
| B-1 「WHATWG 7 条合规点完整正确」 | **不成立** | 以 W1–W10 为唯一清单；`finish` 改 EOF 丢弃；`retry` 纯数字；`retry:0` 合法；`id` NUL 检查；BOM 必做 | S0-facts §2；S0-battle B-1；`s3_fields`、`s4_chunk`、`s6_finish_eof` |
| B-2 「`feed` 返回值与回调中断」 | 有条件成立 | 成功返回本次事件数；任何致命 -1 + 终止态；回调非 0 是本块剩余不再解析 | S0-battle B-2；`s5_abort` |
| B-3 「borrow + 深拷贝」 | 有条件成立 | 视图只读、回调返回或下一次调用即失效；`sse_event_copy/free`；ASan 负例 | S0-battle B-3；`s6_copy`、`s6_borrow_uaf` |
| B-4 「S0–S7 分期」 | **不成立** | 重切为可独立验收的能力片；实际 S1–S10 + I-1 | S0-battle B-4；roadmap §5 |
| B-5 「`SseParser::new()` 静态工厂」 | **不成立** | 自由函数 `sse_parser_new()` | S0-facts §1.4/§1.5；S0-battle B-5；[S0-constructor-shapes](S0-constructor-shapes.md) |
| B-6 「retry 流级 + 0 表示未设置」 | 有条件成立 | 流级持久；`has_retry()`/`retry_hint()` 拆分；`retry:0` 为已设置 | 第 4 题裁定；`s3_retry_zero` |
| B-7 「不新增语言能力」 | 有条件成立 | 三个绕法写进文档：自由构造函数、helper 先定义、helper 名不以 `_` 开头 | S0-battle B-7；S0 卡 §2 |
| B-8 「int 返回 + 错误文本」 | 成立 | 四类文本 + 重入文本；码 0–5 | S0-battle B-8；`s5_limits`、`s9_error_codes` |
| B-9 「`max_line_bytes(n)`」 | **不成立（原口径歧义）** | `n` 是内容字节上限；恰好 n 通过、n+1 报错 | 第 5 题裁定；`s5_limits` |
| B-10 「公开 API 面」 | 有条件成立 | 公开面按 S0 卡 §3 冻结；清单外不导出 | S0-battle B-10；S0-closeout E-4 |
| B-11 「`sse_event_copy/free`」 | 有条件成立 | copy 失败返回 0；free 只接受 copy；`data` 按 `data_len` 拷贝 | S0-battle B-11；`s6_copy`、`s9_oom` |
| B-12 「纯协议解析器」 | 成立 | 不做 HTTP/LLM/重连/路由 | S0-battle B-12 |
| B-13 「请 CT 给 `Vec<T>.data()`」 | **不成立（撤回）** | 不用 `Vec`；`char *` + 显式容量 | S0-battle B-13 |
| 提案依赖方向 `ct-http → ct-sse` | **不成立（写反）** | `ct-sse → ct-http`；`ct-http` 不得依赖 `ct-sse` | 第 16 题裁定；[S16](S16-dependency-direction.md) |
| 提案 `_xxx` 私有方法 | 不成立（命名不是可见性） | 公开面冻结；清单外不承诺；不扩语言 | S0-facts §2 #2；S0-battle B-10 |
| 提案 `retry` 事件后清零 | **不成立** | 流级持久，跨事件与 `reset` 保持 | S0-facts §4；`s3_retry_zero` |

## 4 被推翻写法（需求定稿中不得再出现）

| # | 提案/旧稿写法 | 现行写法 | 推翻依据 |
| --- | --- | --- | --- |
| 1 | `SseParser::new()` 静态工厂 | `sse_parser_new()` 自由函数 | S0-facts §1.4/§1.5、B-5 |
| 2 | `retry == 0` 表示未设置 | `has_retry()` 判有无；`retry: 0` 是合法已设置值 | 第 4 题、B-6 |
| 3 | `max_line_bytes(n)` 的 `n` 含 NUL 容量 | `n` 是内容字节上限 | 第 5 题、B-9 |
| 4 | `finish()` 解析并分发残留 | EOF 丢弃 pending，不分发半事件 | W10、B-1、第 12 题 |
| 5 | 请求 CT 提供 `Vec<T>.data()` | 撤回；`char *` + 显式容量 | B-13 |
| 6 | `ct-http → ct-sse` 依赖方向 | `ct-sse → ct-http` 单向 | 第 16 题、[S16](S16-dependency-direction.md) |
| 7 | `_xxx` 即私有方法 | 公开面按清单冻结；`_xxx` 只是命名约定 | S0-facts §2 #2 |
| 8 | 注册表 `int` 作宿主 | `struct SseRegistry` 宿主，方法按值返回宿主 | 第 3 题、[S8-int-host](S8-int-host.md) |

## 5 缺口与未决（如实登记，不代拟）

| # | 项 | 状态 |
| --- | --- | --- |
| G-1 | 第 9/10 题裁定与实测 | **未留档**。本仓库没有可引用的原文；不把相邻结论（分配器、finish）冒充成这两题。若负责人补发，按同一格式补两行。 |
| G-2 | 真实网络分片 | 环境缺口；切点由本仓库选定（整块/逐字节/伪随机 1..7），真实 TCP 断点无法穷举（[S9](S9-allocator.md) §5.2） |
| G-3 | 退出时可达内存 | 环境缺口；macOS ASan 不支持 `detect_leaks`，需 Linux CI（[S9](S9-allocator.md) §5.1） |
| G-4 | `ct` / `ct-ast` 等价性 | 未证；golden 由 `ct` 跑出，不计入门禁通过数（[S9](S9-allocator.md) §5.3） |
| G-5 | 集成门禁取包瞬时失败 | 2026-11-15 首次 `ct get` 报 `git fetch ... failed`（退出 1），复跑同一命令通过（`ok i1_http_stream`）。发布 tag 源码也可按 `git clone --branch v0.1.0` 审计（[S16](S16-dependency-direction.md) §2.1、§5）。记录保留，不作为阻塞 |
| G-6 | 块内残留长度 | 不可观测（第 12 题裁定），只有计数快照 + 行为断言（S0 卡 §9-5） |

## 6 结论

1. 提案原文保留，但**不能作为需求**；需求定稿只取裁定后的口径。
2. 十六个问题里 14 个有可追依据，2 个（9/10）登记为未留档，不编造。
3. 评估层不写实现与排期；实现证据在夹具与提交，排期在 roadmap，卡在 `docs/phases/`。

# ct-sse 路线图

> 定位：五层产物中的**第四层**。写片序、依赖、验收判据、版本落点；不写需求口径
> （[需求定稿](../requirements.md)），不重复评估（[evaluation](../reviews/evaluation.md)）。
> 日期：2026-11-15。当前包版本 **0.11.0**。语言基线 CT v0.53.0。

## 1 现在到哪了

已完成并绿的片：契约冻结、解析主体、字段持久、跨 chunk、边界与中断、copy、注册表、
分配器与 OOM、计数、finish 可观测性、重入拒绝、真实对接、文档与示例收尾（PH-11）、
诊断级别门禁（PH-12）。逐片的状态、红证与判据见 `docs/phases/PH-01…PH-12/card.md`；门禁命令见 §6。
台账现状见 [planning-audit](../reviews/planning-audit.md)。

**集成门禁**：2026-11-17 在 CT v0.63 下复核，ct-http 0.1.0 的 `ct.pkg` 缺 `publisher`，
`ct get` 被新编译器拒绝；改用 ct-http 0.2.1 + `ct build --locked` 后通过
（`ok i1_http_stream (ct-http 0.2.1, real loopback chunks)`）。2026-11-15 的 0.1.0 记录
（首次 `ct get` 瞬时失败、复跑通过）保留为历史，不列为阻塞项；审计见
[S16](../reviews/S16-dependency-direction.md) §2.5、[S13](../reviews/S13-http-integration.md) §8。

## 2 片序总表

> `version-minor` 是收口时应达到的 MINOR（6.7 V-1）。`PH-01…PH-10` 是**回溯补卡**：
> 实现与红证都发生在卡之前，卡面如实写明顺序；不推倒已绿实现。

| 片 | 目标（一句话） | version-minor | 状态 | 依赖 | 退出判据（二值） |
| --- | --- | --- | --- | --- | --- |
| PH-01 | 类型/构造/查询/Drop 骨架 | 1 | 已收口（回溯卡） | S0 契约 | `bash test/run.sh s1_construct` 退出 0 |
| PH-02 | 行切分、字段解析、data 分发最小闭环 | 2 | 已收口（回溯卡） | PH-01 | `bash test/run.sh s2_basic`；`s2_syntax` 均退出 0 |
| PH-03 | event / id / retry 语义 | 3 | 已收口（回溯卡） | PH-02 | `bash test/run.sh s3_fields`；`s3_retry_zero`；`s3_state` 均退出 0 |
| PH-04 | 跨分片行结束与 BOM | 4 | 已收口（回溯卡） | PH-03 | `bash test/run.sh s4_chunk`；`s4_bom_edge` 均退出 0 |
| PH-05 | 行上限、终止态、中断 | 5 | 已收口（回溯卡） | PH-04 | `bash test/run.sh s5_limits`；`s5_abort` 均退出 0 |
| PH-06 | `sse_event_copy` / `sse_event_free` | 6 | 已收口（回溯卡） | PH-05 | `ASAN=1 bash test/run.sh s6_copy`；`s6_borrow_uaf` 退出 0 |
| PH-07 | README、示例、集成形态 | 7 | 已收口（回溯卡） | PH-06 | `bash test/run.sh s7_integration` 退出 0 |
| PH-08 | 值返回注册表（含 0.8.1 retry 修正） | 8 | 已收口（回溯卡） | PH-07 | `bash test/run.sh s8_registry` 退出 0 |
| PH-09 | 分配器注入、OOM、计数、finish 可观测性、I-1 | 9 | 已收口（回溯卡） | PH-08 | `s9_oom`、`s9_alloc_count`、`s9_finish_clean`、`s9_error_codes` 退出 0；`test/integration.sh` 0 |
| PH-10 | 回调重入拒绝 | 10 | 已收口（回溯卡） | PH-09 | `bash test/run.sh s10_reentrant`；`s10_reentrant_state` 退出 0 |
| PH-11 | 文档与示例收尾 | 11 | 已收口 | PH-10 | 见 §3.1；`check_links`/`check_api` 退出 0，三个示例退出 0 |
| PH-12 | 诊断格式落地后替换门禁读文本 | 12 | 已收口（0.12.0） | PH-11；CT 结构化诊断 | 见 §3.2 |
| PH-13 | Linux CI 补 LSan | 13 | 阻塞（CI 环境） | PH-11；Linux runner | 见 §3.3 |
| PH-14 | ct-http 若含 SSE 逻辑的下沉跟进 | 14 | 已复核（v0.2.1 无工作项） | PH-11；ct-http 变更 | 见 §3.4 |

**片序理由**：PH-01–PH-10 按可独立验收的能力切；PH-11 先把文档/示例收口，避免后续片
在过期文档上施工；PH-12 已随 CT v0.63 的 JSON 诊断收口；PH-13/14 仍受环境/外部变更约束，
条件不具备时保持阻塞，不插入已完成片的窗口。

## 3 未收口片的判据与交付物

### 3.1 PH-11 文档与示例收尾（0.11.0，已收口）

> 保留判据作为历史锚点；PH-11 已于 0.11.0 收口，不再是待开工片。

- 交付物：`README.md`、`docs/README.md`（文档索引）、`docs/snippets/`（可运行示例）。
- 任务：
  - T1 文档索引与链接检查：所有相对链接目标存在；`python3 tools/check_links.py` 退出 0。
  - T2 README 与生成头对齐：公开符号表与 `nm` 导出的 `sse_` 符号集合完全一致。
  - T3 示例补齐：注册表、copy、错误码三条可运行示例，各自有 expected 输出。
- 退出判据：
  1. `python3 tools/check_links.py docs README.md` 退出 0（0 个缺失链接）。
  2. `bash test/run.sh <example>` 对三个示例均退出 0，且 `diff` 无差异。
  3. README 的 API 表行数 = `nm` 导出符号数（脚本比对，退出 0）。
  4. 任务清单每项可独立验收。
- 回滚：删除 `docs/README.md`、`docs/snippets/` 与 `tools/check_links.py`，README 回退到
  0.10.0 版本；不影响 `sse/` 与既有夹具。

### 3.2 PH-12 诊断格式替换门禁读文本（0.12.0，已收口）

- 触发条件：CT 提供按级别可判定的结构化诊断（或等价稳定输出），不再依赖 `warning:` 文本。
  已满足：CT v0.63.0 的 `--diagnostics=json` 对 CT 语义诊断输出 JSON；C 编译警告由
  `-Werror` 升级为错误、以构建退出码判定。探针与限制见
  [diagnostics-format](../reviews/diagnostics-format.md)。
- 交付物：`test/run.sh` 的警告判定、`docs/reviews/` 的诊断格式记录。
- 退出判据：
  1. `test/run.sh` 中不再出现 `grep -q 'warning:'`（`grep -c` 为 0）。
  2. 注入一个未使用参数：门禁退出 1，提示来自诊断级别，而不是文本匹配。
  3. 全量夹具在无警告构建下退出 0。
  4. 任务清单每项可独立验收。
- 回滚：还原 `test/run.sh` 的警告段；不影响夹具本身。

### 3.3 PH-13 Linux CI 补 LSan（0.13.0，阻塞）

- 触发条件：有可用的 Linux CI runner，且能安装/运行 CT v0.63.0。
- 交付物：CI 配置、`docs/reviews/` 的 LSan 运行记录。
- 退出判据：
  1. `ASAN_OPTIONS=detect_leaks=1 bash test/run.sh <全部夹具>` 在 Linux 上退出 0，且日志
     无 `LeakSanitizer` 报告。
  2. macOS 上同一命令仍退出 0（不因新增配置回归）。
  3. 任务清单每项可独立验收。
- 阻塞说明：macOS 的 ASan 不支持 `detect_leaks`（实测原文见
  [S9-allocator](../reviews/S9-allocator.md) §5.1）；本机无 Linux runner（`docker` 不存在，
  `podman machine` 与 `colima` 在当前沙箱下无法创建 VM，原文见
  [planning-audit](../reviews/planning-audit.md) GAP-2）。在环境到位前登记为缺口，不用计数器
  冒充泄漏结论。
- 回滚：移除 CI 配置；本地门禁不变。

### 3.4 PH-14 ct-http 若含 SSE 逻辑的下沉跟进（0.14.0，条件未触发）

- 触发条件：ct-http 的后续版本出现 SSE 解析、事件分发、`text/event-stream` 判断或
  `Last-Event-ID` 处理（2026-11-17 复核 v0.2.1，提交 `1121bbc`，`http/`、`test/` 为 0 处；
  见 [S16](../reviews/S16-dependency-direction.md) §2.4）。
- 交付物：审计记录、给 ct-http 的接口建议（只报告，不改对方仓库）。
- 退出判据：
  1. `grep -rni -E "event-stream|server-sent|last-event|data:|event:" http/` 的结果逐条归类，
     无未归类的 SSE 语义。
  2. 若存在 SSE 语义：给 ct-http 的 issue/提案已提交（有链接），本包不改对方代码。
  3. 任务清单每项可独立验收。
- 当前状态：**无工作项**；不为了凑片而制造改动。
- 回滚：仅文档，回滚即删除对应记录。

## 4 版本落点与发布前置条件

| 项 | 口径 |
| --- | --- |
| 当前版本 | `0.12.0`（PH-12 收口） |
| 下一版 | `0.13.0`（PH-13 收口；MINOR 与 PH 编号一一对应） |
| 历史 PATCH | `0.8.1` 是 PH-08 窗口内的 fix（第 4 题 retry 查询拆分），不另立 phase |
| 版本规则 | 每个 phase 收口 MINOR=PH 编号、PATCH 归零；phase 内 fix 才 +PATCH（6.7） |
| 发版前置 | 全部单包夹具绿；集成门禁绿；零警告；API 与 S0 卡 §3 一致；CHANGELOG 完整 |
| tag | 每个 phase 收口创建 annotated tag `v<version>` 并指向收口提交（6.7 V-7）；`v0.11.0` 已推送，`v0.12.0` 已建（本地） |
| push | 分支推送需 owner 明确授权；phase tag 随收口创建，但仅在收口提交已可从远端追溯时才推（V-7 ④） |
| 集成门禁 | ct-http 0.2.1 + `ct build --locked`，2026-11-17 通过；0.1.0 的瞬时失败是历史记录 |
| 包清单 | 已完成：`ct.pkg` 含 `publisher = ct`、`ns-root = .`，`ct pkg check .` 输出 `ok: 4 criteria` |
| 发布 tag | `v0.11.0` 已建并推送；`v0.12.0` 已建（本地，收口提交未推送，按 V-7 ④ 不推 tag） |

## 5 与提案 S0–S7 的差异

提案分期被判「不可独立验收」（[S0-battle](../reviews/S0-battle.md) B-4）。实际切分如下：

| 提案 | 处置 | 原因 |
| --- | --- | --- |
| S0 契约冻结 | 保留为**前置相**，不占 PH 编号、不移动版本 | 它只冻结契约，没有可执行交付物；版本 0.0.0 不成立 |
| S1 类型/错误骨架 | 保留 → PH-01 | 构造/查询/Drop 可独立验收 |
| S2 行读取与字段解析 | 保留 → PH-02 | 加行上限、跨 feed、CR/LF 用例后独立 |
| S3 字段语义 | 保留 → PH-03；第 4 题的 retry 拆分作为 PH-08 窗口的 0.8.1 fix | 语义片可独立验收；retry 修正是后续裁定 |
| S4 分发/回调 | 拆：最小分发在 PH-02，跨分片/BOM 在 PH-04 | 原 S4 混了「事件组装」与「分片」，无法单独红 |
| S5 reset/limits | 合并进 PH-05（限额/终止态）与 PH-03/04 的 reset 用例 | reset 是边界，不是收尾；原 S5 作为独立相太晚 |
| S6 公开 API/错误文本 | 拆：copy/free → PH-06；公开面与文本随 PH-01/05 落地 | 原 S6 把两个目的塞进一片，违反 T-1 |
| S7 测试/文档 | 缩为 PH-07（示例与文档），测试随各片走 | 测试不是独立实现相 |
| （新增）注册表 | PH-08 | 负责人指定的形态，提案没有 |
| （新增）分配器/OOM/计数 | PH-09 | 第 6/7/8 题裁定 |
| （新增）finish 可观测性 | PH-09（test-only，不移动版本） | 第 12 题裁定 |
| （新增）真实对接 | PH-09（I-1，独立集成门禁） | 第 13 题裁定 |
| （新增）重入拒绝 | PH-10 | 第 15 题裁定 |
| （新增）覆盖表 | 横切（S14），不单独成片 | 它补的是既有片的断言，不是新能力 |
| （新增）依赖方向 | 横切（S16），不单独成片 | 文档/审计，不改行为 |

**取消**：提案的「请求 CT 提供 `Vec<T>.data()`」（B-13 撤回）、「静态工厂」
（B-5 不成立）、「`ct-http → ct-sse` 方向」（第 16 题写反）。

## 6 门禁总表（当前可跑）

单包门禁（每个都必须退出 0）：

```console
$ for t in s1_construct s2_basic s2_syntax s3_fields s3_retry_zero s3_state \
    s4_chunk s4_bom_edge s5_limits s5_abort s6_copy s6_finish_eof s7_integration \
    s8_registry s9_oom s9_alloc_count s9_finish_clean s9_error_codes \
    s10_reentrant s10_reentrant_state ex_registry ex_copy ex_error_codes; do
    bash test/run.sh "$t" || exit 1
  done
$ bash test/gates/g12_warning.sh
```

ASan 子集：

```console
$ ASAN=1 bash test/run.sh s6_copy
$ ASAN=1 bash test/run.sh s6_borrow_uaf   # 期望 heap-use-after-free 后 abort
$ ASAN=1 bash test/run.sh s8_registry
$ ASAN=1 bash test/run.sh s9_oom
$ ASAN=1 bash test/run.sh s9_alloc_count
$ ASAN=1 bash test/run.sh s9_finish_clean
$ ASAN=1 bash test/run.sh s10_reentrant
$ ASAN=1 bash test/run.sh s10_reentrant_state
```

独立集成门禁：

```console
$ bash test/integration.sh   # 0 通过、1 失败、2 前置条件缺失
```

## 7 登记缺口（不立 phase）

| # | 缺口 | 为什么不立 phase |
| --- | --- | --- |
| G-1 | 真实 TCP 分片无法穷举 | 没有二值判据；只能登记切法（整块/逐字节/伪随机） |
| G-2 | 退出时可达内存（macOS 无 LSan） | 有环境依赖，已由 PH-13 承接 |
| G-3 | `ct`/`ct-ast` 等价性未证 | 第二个前端不可用；不把数量计入门禁通过 |
| G-4 | 块内残留长度不可观测 | 第 12 题裁定不加接口；由计数快照+行为断言覆盖 |
| G-5 | 第 9/10 题裁定未留档 | 不代拟；补齐后补评估表，不单独成片 |
| G-6 | 打包与发版待办 | 不新增 phase；包清单已完成，`v0.11.0` 已建并推送；见 [backlog](backlog.md) |

# 包外转入事项（ct-sse 认领）

> 来源：从 CT 仓移出的包外清单中属于本仓的条目。
> 本文只做认领与状态登记，不代表前置能力已具备，也不改变契约或版本。
> 前置能力：**C1** `ct get` 落 store 并读 `publisher`；**C2** `ns-root` 进 `-I`；
> **C3** `ct build` 默认读 lock。三者均未落地。

## 1 认领表

| ID | 来源 | 要做什么 | 前置能力 | 验收方式 | 当前状态 |
| --- | --- | --- | --- | --- | --- |
| EXT-SSE-01 | 提案 §10 S4 | `ct.pkg` 补 `publisher = ct`、`ns-root = .` | C1、C2 | ① `ct.pkg` 含这两个字段；② `ct get` 后 store 能读到 `publisher`；③ `-I` 按 `ns-root` 解析 `import`；④ 生成头与公开符号集不变（`python3 tools/check_api.py` 退出 0） | **认领 / 阻塞**：前置未落地。工作区**已有未提交改动**（`ct.pkg` 的 `publisher`/`ns-root`、`README.md` 的 `-I .`），按指令不提交、不丢弃，登记为待决（§2） |
| EXT-SSE-02 | 提案 §10 S4 | 打 `v0.11.0` | 通用 tag 规则：annotated、默认分支可达、`version` 与 tag 一致；C1/C2 完成后再执行 | ① `git cat-file -t v0.11.0` 输出 `tag`；② `git branch --contains v0.11.0` 含默认分支；③ `grep '^version' ct.pkg` 为 `0.11.0`；④ `git describe --tags --exact-match` 为 `v0.11.0` | **认领 / 阻塞**：未创建 `v0.11.0`；现有 `backup/pre-s4-rollback` 是备份 tag，不是发布 tag |
| EXT-SSE-03 | CT 侧 LANG-2（缺陷已修） | 决定静态工厂是否回退为类型工厂 | 无（本仓自选；不作为对齐判据） | 决策记录 + 公开面不变：`grep -rn "SseParser::new" sse test README.md` 为 0；`python3 tools/check_api.py` 退出 0 | **已决：不回退**，保留 `sse_parser_new()`（理由见 §3） |

## 2 待决项（不得擅自处理）

工作区在本次认领时存在以下未提交改动，**既未提交也未丢弃**：

- `ct.pkg`：新增 `publisher = ct`、`ns-root = .`（对应 EXT-SSE-01）。
- `README.md`：构建示例的 `-I /path/to/ct-sse` 改为 `-I .`（与 `ns-root` 同一批）。

待决原因：EXT-SSE-01 的前置 C1/C2 未落地；提交这批改动等于提前宣告能力可用。
处理建议：等 C1/C2 落地后，用一次独立提交完成 EXT-SSE-01，并同步验收；在那之前保持现状。
版本号 `0.11.0` 已由 PH-11 收口写入，本次**未移动**，也不因 EXT-SSE-02 提前打 tag。

## 3 EXT-SSE-03 决策记录

**结论：不回退为类型工厂，继续使用自由函数 `sse_parser_new()`。**

理由：

1. 契约已冻结（S0 卡 §3）；`SseParser::new()` 从未成为需求，只是当时不可用的备选形态。
2. LANG-2 修复只说明“现在可能可用”，不构成“应该切换”。切换会改变公开面、示例与全部夹具，
   没有功能收益。
3. 本仓的构造形态裁定是“自由函数 + 显式 `delete`”（研判评估第 2 题）；该裁定仍成立。
4. 若未来确实需要类型工厂门面，应作为新需求/新 phase 卡评估，而不是当作缺陷回退。

验收：代码、夹具与 README 中无 `SseParser::new` 用法；`tools/api_surface.txt` 不变；
`python3 tools/check_api.py` 退出 0。

## 4 需要 owner 拍板的点

1. C1/C2 落地后，是否立即执行 EXT-SSE-01 并接着执行 EXT-SSE-02；tag 与 push 由谁执行
   （本仓当前不 push、不打 tag）。
2. EXT-SSE-03 的“不回退”结论是否接受；若要求类型工厂门面，另立需求与 phase 卡。
3. §2 的未提交改动由谁、在什么时点提交；本仓不擅自提交或回退。

## 5 与现有路线图的关系

- 这三条不新增功能 phase，不进入 PH-12/13/14 的施工窗口；EXT-SSE-01/02 是发布与包元数据事项，
  EXT-SSE-03 是已决的契约问题。
- 版本仍为 `0.11.0`；tag、push、跨仓操作均不在本仓当前授权内。

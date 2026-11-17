# 本仓待办与已决事项

> 只记录本仓自己的任务与决定：为什么需要、要做什么、前置是否满足、怎么验收。
> 本文不改变契约与版本。前置条件按本仓能直接观察到的能力判断。

## 0 本轮重判依据

包管理器现状已逐项核对，以下能力可用：

1. store 按发布方、包名、版本落盘。
2. `publisher` 必填。
3. `ns-root` 必填，并参与 include 根展开。
4. lock 文件含发布方与单元根。
5. `ct build` 默认读 lock，并自动补 include 根。
6. 索引含发布方、包名、版本、单元根等六个字段。

结论：包清单相关事项不再受能力阻塞；发布 tag 只受先后顺序与授权约束。
原「前置未满足、保持阻塞」的判断作废。

## 1 待办：包清单补充发布者与命名根

**为什么需要**：消费方通过包管理器取包时，需要知道发布者和 import 的命名根。此前 `ct.pkg`
只有 `name`、`version`、`licence`、`requires`，取包方无法从清单里得到这两项信息。

**要做什么**：在 `ct.pkg` 增加 `publisher = ct` 与 `ns-root = .`；同步把 README 构建示例的
include 根改成包根。

**前置**：已满足。store 能按发布方落盘并读 `publisher`，`ns-root` 参与 include 根展开，
`ct build` 默认读 lock 并自动补 include 根。

**怎么验收**：
1. `ct.pkg` 含 `publisher` 与 `ns-root` 两个字段。
2. 取包后 store 路径能体现发布方、包名与版本。
3. 消费方不手写包内子目录的 `-I`，`import sse::sse` 仍能解析。
4. `python3 tools/check_api.py` 退出 0（公开面不变）。

**当前状态**：已完成。`ct.pkg` 含 `publisher = ct` 与 `ns-root = .`，README 构建示例改用
`-I .`，见提交 12b4883；`ct pkg check .` 输出 `ok: 4 criteria`，`import sse::sse` 以仓库根
为 include 根仍能解析。许可统一为 MIT（`licence = MIT`、`LICENSE` 为 MIT）。

**本仓的分期判断**：不单独立 phase 仍然成立——它是包清单配置补全，不新增解析能力、不改公开面。
但「保持阻塞」不成立：它是当前第一项可执行的维护任务，应先于发布 tag。

## 2 待办：发布 tag `v0.11.0`

**为什么需要**：`0.11.0` 已收口，需要一个与 `version` 一致的 annotated tag 作为发布点，
否则消费方无法按 tag 取到这一版。

**要做什么**：在默认分支可达的提交上创建 annotated tag `v0.11.0`。

**前置**：没有能力前置；按顺序等第 1 项的包清单改动先落地。tag 与推送需要 owner 明确授权，
本轮不打 tag。

**怎么验收**：
1. `git cat-file -t v0.11.0` 输出 `tag`（annotated）。
2. `git branch --contains v0.11.0` 包含默认分支。
3. `grep '^version' ct.pkg` 为 `0.11.0`。
4. `git describe --tags --exact-match` 输出 `v0.11.0`。

**当前状态**：已完成。annotated tag `v0.11.0` 已创建并推送（tag 对象 `ac14e58`，指向收口提交
`ca1ded6`；`git ls-remote --tags origin` 可见）。`backup/pre-s4-rollback` 是备份 tag，与发布 tag
分开。2026-11-17 复核：`git cat-file -t v0.11.0` 输出 `tag`，`git describe --tags --exact-match`
输出 `v0.11.0`。

**本仓的分期判断**：不单独立 phase。它是发版动作，不是能力片；等第 1 项验收后，
按“确认版本 → 打 annotated tag → 校验可达与一致性 → owner 推送”一次做完。

## 3 已决：构造形态保持自由函数

**背景**：类型工厂（把构造挂在类型上）曾是候选形态；当前公开契约已冻结为自由函数
`sse_parser_new()`，代码、示例与夹具都按这个形态落地。

**决定**：不回退为类型工厂。

**理由**：
1. 构造形态已经写进冻结契约，切换会改变公开面、示例与全部夹具。
2. 类型工厂不带来功能收益；它只是另一种写法，不是缺陷修复。
3. 若未来确实需要类型工厂门面，应作为新需求与新 phase 评估，而不是回退既有契约。

**验收**：`grep -rn "SseParser::new" sse test README.md` 为 0；`tools/api_surface.txt` 不变；
`python3 tools/check_api.py` 退出 0。

**本轮重判**：与包管理器能力无关，结论不变；已完成，不立 phase。

## 4 需要 owner 拍板（2026-11-17）

1. **GAP-1 门禁层**：是否批准另立一个 phase，把 `tools/check.sh` 的 G0–G9、`issues/`、
   `docs/decisions/`、`docs/snippets/` 补齐；在它完成前，项目按 11.5 L-3 处于“已开 phase 可收口、
   不得新开 phase”的状态。见 [planning-audit](../reviews/planning-audit.md) GAP-1。
2. **PH-13 Linux runner**：是否提供可运行 CT 的 Linux runner（或授权用远端 CI）；没有 runner
   就无法产出 E-1 要求的 LSan 原始输出。
3. **PH-12 判定口径**：本轮按“CT JSON 诊断 + C 警告由 `-Werror` 升级、构建退出码判定”收口；
   若要求必须由 CT 直接结构化输出 C 编译警告，则 PH-12 仍需等待 CT 能力，本轮不伪装收口。

## 5 与其他文档的关系

- 这三项不新增功能 phase，不进入 PH-12/13/14 的施工窗口。
- 版本：PH-11 收口为 `0.11.0`；PH-12 收口时按 6.7 移到 `0.12.0`。
- tag：`v0.11.0` 已建并推送；下一 phase 收口按 6.7 V-7 建 `v0.12.0`。
- 发布前置条件与 gate 清单见 [roadmap](roadmap.md) §4、§6。

## 6 本仓的进度判断与下一步

| 条目 | 是否立 phase | 完成度 | 下一步 | 现在推不推 |
| --- | --- | --- | --- | --- |
| 包清单补充发布者与命名根 | 否 | 已完成（`12b4883`，`ct pkg check .` = `ok: 4 criteria`） | 无 | 已收口 |
| 发布 tag `v0.11.0` | 否 | 已完成（annotated，已推送） | 无 | 已收口 |
| 构造形态保持自由函数 | 否 | 已完成（决定已落文档） | 无 | 已收口 |
| PH-12 诊断级别门禁 | 是 | 可开工（CT v0.63） | 红证 → 实现 → 收口 `0.12.0` | 推 |
| PH-14 ct-http 0.2.1 复核 | 否 | 已完成（0 处 SSE 语义） | 无 | 已收口 |
| PH-13 Linux LSan | 是 | 阻塞（无 Linux runner） | 等环境 | 不推 |
| GAP-1 门禁层 | 待拍板 | 未开始 | 用户批准后新开 phase | 等批准 |

**整体判断**：PH-11 已收口；PH-12 已具备开工条件；PH-14 复核无工作项；PH-13 仍被环境阻塞。
“全部 phase 完成”不是可交付目标，可交付目标是**可执行 phase 全部收口 + 阻塞项留下可复现证据**。

**下一步决定**：先收口 PH-12，再完成 PH-14 的 0.2.1 复核记录；PH-13 保持阻塞；GAP-1 等 owner 裁定。

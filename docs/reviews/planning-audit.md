# 规划与台账核对（2026-11-17）

> 触发：用户要求先评估 phase 规划是否混乱，无问题后推进到全部 phase 完成。
> 定位：评审层的核对记录，不改需求口径、不改契约。结论先行：
> **片序与依赖没有混乱；混乱在台账状态与门禁层。** 逐项证据与处置如下。

## 1 片序核对：通过

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 编号连续、无重复 | 通过 | `docs/phases/PH-01…PH-14` 与 `S0` 一一对应 |
| `version-minor` 与编号一致 | 通过 | PH-11=11、PH-12=12、PH-13=13、PH-14=14 |
| 依赖无环、无交叉 | 通过 | PH-01→…→PH-11；PH-12/13/14 均只依赖 PH-11 |
| 回溯片未推倒已绿实现 | 通过 | PH-01…PH-10 卡面明写“回溯补卡”，实现提交在其后 |
| 当前版本与最近收口片一致 | 通过 | `ct.pkg` 与 README 均为 `0.11.0`，对应 PH-11 |

结论：**不需要重排 phase，也不需要新开替代片。** 后续工作是在既有片序上收口，而不是重新分期。

## 2 台账与现状不一致（本轮已修或登记）

| # | 现象 | 证据 | 处置 |
| --- | --- | --- | --- |
| A-1 | 规范 pin 落后两版：项目块头 `1.10.0`，主规范 `1.15.0` | 修前 `sync-agents.sh --check AGENTS.md` 退出 1，提示期望 1.15.0 / 实际 1.10.0 | 已从规范来源 `--write` 刷新块与全文副本，`--check` 退出 0；块外 pin 注释同步到 1.15.0 |
| A-2 | `v0.11.0` 已存在且已推送，文档却说“未执行 / 现在不打 tag” | `git cat-file -t v0.11.0` → `tag`；`git ls-remote --tags origin` → `ac14e58… refs/tags/v0.11.0`（指向 `ca1ded6`） | 更新 roadmap §4 与 backlog §2/§6，按“已打 tag、已推送”记录 |
| A-3 | roadmap §3 标题是“未开工片”，却把已收口的 PH-11 放在 §3.1 | `docs/planning/roadmap.md:45-60` | §3 改为“未收口片的判据与交付物”，PH-11 判据保留为历史锚点并标注已收口 |
| A-4 | AGENTS.md 0.1 说“门禁 / snippet / Issue / 决策 / 版本落点均未建”，与仓库现状不符 | 修前 AGENTS.md 0.1；实际 `ct.pkg`、README 有版本行，`tools/check_links.py`、`tools/check_api.py` 已存在 | 0.1 改为实际状态；仍缺的项按 GAP-1 登记，不写成“已建” |
| A-5 | phase 卡任务清单缺 `effort`（6.6 T-2）；PH-12/13/14 无红证计划（T-7） | `grep -l effort docs/phases/PH-*/card.md` 为空 | PH-12 开卡前补齐；PH-13/14 保持阻塞卡并补 `effort` / `no-test` 说明 |
| A-6 | `docs/session-map.md` 只有日期 / 会话 / 产出三列，9.5 要求四列 | 原文件 16 行 | 改为任务 / 对话 / 角色 / phase 四列 |
| A-7 | PH-14 的审计基线停在 ct-http 0.1.0，而 0.2.0/0.2.1 已发布 | `git ls-remote --tags` 见 v0.2.0、v0.2.1；S16 原文写 0.1.0 | 复核 0.2.1（提交 `1121bbc`）：`http/`、`test/` 无 SSE 语义，更新 S16 与 PH-14 卡；仍无工作项 |
| A-8 | PH-12 的阻塞条件“CT 无结构化诊断”已不成立 | `ct --version` → `v0.63.0`；`ctc check … --diagnostics=json` 对 CT 语义错误输出 JSON（含 `severity`），`ct build` 也输出 `warnings` 数组 | 按“CT 诊断用 JSON、C 编译警告用 `-Werror` + 退出码”收口；细节见 [diagnostics-format](diagnostics-format.md) |

## 3 真正的缺口（不改写为通过）

### GAP-1 门禁层未落地

`AGENTS.md` 0.1 从立项起就写“`tools/check.sh` 待建”，但 PH-01…PH-11 的实现与收口都没有补。
现状：

```console
$ ls tools
api_surface.txt  check_api.py  check_links.py
$ ls issues
ls: issues: No such file or directory
```

影响：

1. G0/G1/G2/G4/G5/G6/G7/G8/G9 没有可执行入口，phase 收口的“已收口”只能由 `test/run.sh` 与人工对照支撑，不是 6.4 的机械判据。
2. 没有 `issues/`，G6 的“每个 Issue 只有一个去向”无从检查；也没有 `docs/decisions/`，关键裁定散在 reviews 里。
3. 按 11.5 L-3，未落库/未纳管会拦住**新开** phase；已开 phase 仍可收口。因此本轮只收口既有 PH-12，不新开 phase。

处置：登记为 GAP-1。这里有一个治理死锁：G0 因缺 `tools/check.sh` 失败，按 11.5 L-3
“不得开新 phase”；而补齐门禁又不宜绕过门禁流程。可行路径只有两条：①作为**维护任务**
（不立 phase，只补 `tools/check.sh` 与负例），或 ②用户签字登记 `deviation:` 后按新 phase
处理。本轮不擅自选，也不在缺门禁时宣称 G0–G9 全绿。

### GAP-2 PH-13 曾被环境阻塞（2026-11-17 已解除）

```console
$ docker --version
bash: docker: command not found
$ podman machine list
Error: creating lockfile ... operation not permitted
$ colima version
time="…" level=fatal msg="cannot make required directory: mkdir /Users/samxx/.colima: operation not permitted"
```

macOS 本机没有 Linux runner，ASan 又不支持 `detect_leaks`（[S9-allocator](S9-allocator.md) §5.1）。
PH-13 的 E-1 要求 Linux 上的原始运行日志，无法用 macOS 计数器替代。**2026-11-17 已解除**：
用户提供 podman Ubuntu 24.04 容器，Linux CT 从本地源码构建；23 条夹具 LSan 全绿，负例
可触发 `LeakSanitizer`，见 [lsan-linux](lsan-linux.md)。本段保留原始阻塞证据。

## 4 结论与推进顺序

1. **片序不混乱**，不需要重排；本轮不新开 phase。
2. 先修台账（A-1…A-6），再按既有卡收口 PH-12/PH-13；PH-14 只做 0.2.1 复核。
3. “全部 phase 完成”不是可交付目标：PH-13 已解除，PH-14 仍无工作项。可交付目标是
   **可执行 phase 全部收口 + 无工作项的片留下复核证据**。
4. GAP-1 是下一轮的第一优先项；在它补齐前，任何“G0–G9 全绿”的宣称都不成立。

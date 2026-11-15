# PH-02：行切分、字段解析、data 分发最小闭环

> 编号 `PH-02`；目录 `docs/phases/PH-02/`；`version-minor` 2；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**；顺序见 §5。
> 依据：[S0 card](../S0/card.md) W2–W5、[S14](../../reviews/S14-coverage.md)。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 从字节块切行、解析 `data` 字段、在空行分发 `message` 事件 |
| 范围 | 做：行缓冲、空行分发、data 追加与单 LF 去除、空 data 事件；不做：event/id/retry、分片边界、上限 |
| 交付物 | `sse/sse.h.ct` 解析主体；`s2_basic`、`s2_syntax` 夹具与期望输出 |
| 依赖 | PH-01 |
| 规范版本 | 1.10.0 |
| version-minor | 2 |
| 已知风险 | 只去掉一个前导空格/一个末尾 LF 的边界；无 data 字段与空 data 的判定 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | `s2_basic` 夹具（先红） | `bash test/run.sh s2_basic`（红） | `7d8ee05` | 是 |
| T2 | 最小闭环实现 | `bash test/run.sh s2_basic` | `b07740e` | 是 |
| T3 | `s2_syntax` 覆盖缺口夹具（第 14 题补） | `bash test/run.sh s2_syntax` | 本次提交 `test(sse): S14 覆盖缺口夹具` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | 多行 data → `len=10`，只去一个末尾 LF | `bash test/run.sh s2_basic` |
| E-2 | `data:\n\n` → 1 次空 data 事件；无 data 的块 0 次 | 同上 |
| E-3 | 注释含冒号、两个空格、第一个冒号、无冒号、大小写敏感、`data: a\ndata:` 逐条正确 | `bash test/run.sh s2_syntax` |
| E-4 | 构建零警告 | `test/run.sh` 的 `warning:` 检查 |
| E-5 | 任务清单每项可独立验收（6.6 T-6） | 三条 `verify` 分别单跑 |

## 4 回滚

`git revert b07740e` 后 `s2_basic` 红；T1 可单独 revert。`s2_syntax` 是纯增量夹具，
revert 本次提交即移除，不影响实现。

## 5 顺序与红证

- 红：`7d8ee05 test(sse): S2 红`（版本仍 0.1.0）。
- 绿：`b07740e feat(sse): S2 最小解析闭环`（0.2.0）。
- `s2_syntax` 是第 14 题补的锁，**首跑即绿**：实现已正确，无法在不破坏已交付实现的前提下
  制造红证；按「先实现、后补锁」登记（[S14](../../reviews/S14-coverage.md) §4.1）。

## 6 收口记录

- 2026-11-15：`s2_basic`、`s2_syntax` 均 `ok`；版本 0.2.0；仅本地提交。

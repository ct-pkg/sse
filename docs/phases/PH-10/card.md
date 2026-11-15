# PH-10：回调重入拒绝

> 编号 `PH-10`；目录 `docs/phases/PH-10/`；`version-minor` 10；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**；顺序见 §5。
> 依据：第 15 题裁定；S0 卡 C-2。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 回调执行期间禁止反向改写 parser；唯一提前终止是回调返回非 0 |
| 范围 | 做：`in_callback` 标志、六类变更方法入口检查、错误码 4、终止后 `reset` 可复用；不做：重入支持、排队/复制半解析状态 |
| 交付物 | `sse/sse.h.ct` 重入守卫；`s10_reentrant`、`s10_reentrant_state` 夹具 |
| 依赖 | PH-09 |
| 规范版本 | 1.10.0 |
| version-minor | 10 |
| 已知风险 | 检查必须在生产构建生效；`reset`/free 只置错不执行；错误码不得被后续动作冲掉 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | `s10_reentrant` 夹具（先红） | `bash test/run.sh s10_reentrant`（红） | `3ddc090` | 是 |
| T2 | 重入守卫实现 | `bash test/run.sh s10_reentrant` | `a2a2f71` | 是 |
| T3 | 六类方法全覆盖夹具（第 14 题补） | `bash test/run.sh s10_reentrant_state` | 本次提交 `test(sse): S14 覆盖缺口夹具` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | 回调内 `feed`/`reset`/`sse_parser_free` 各被拒：-1 或只置错、码 4、文本含 `reentrant` | `bash test/run.sh s10_reentrant` |
| E-2 | 拒绝后 parser 仍可用：`reset` + `feed` 正常出事件 | 同上 |
| E-3 | 回调返回非 0：`feed=-1`、码 3，`reset` 后可复用 | 同上 |
| E-4 | 回调内 `finish`/`on_event`/`max_line_bytes` 同样被拒且未生效 | `bash test/run.sh s10_reentrant_state` |
| E-5 | 任务清单每项可独立验收（6.6 T-6） | 三条 `verify` 分别单跑 |

## 4 回滚

`git revert a2a2f71` 后重入夹具红；`git revert 3ddc090` 移除红夹具。T3 为纯增量，
单独 revert 即移除。

## 5 顺序与红证

- 红：`3ddc090 test(sse): S10 回调重入拒绝红`（版本 0.9.0，红落在上一窗口）。
- 绿：`a2a2f71 feat(sse): S10 回调重入保护`，版本 `0.10.0`。
- T3 首跑即绿，按「先实现、后补锁」登记（[S14](../../reviews/S14-coverage.md) §4.1）。

## 6 收口记录

- 2026-11-15：`s10_reentrant`、`s10_reentrant_state` 均 `ok`；版本 0.10.0；仅本地提交。

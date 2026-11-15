# PH-03：event / id / retry 语义

> 编号 `PH-03`；目录 `docs/phases/PH-03/`；`version-minor` 3；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**；顺序见 §5。
> 依据：S0 card W6–W8、R-2；[S14](../../reviews/S14-coverage.md)。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 固定事件类型、流级 id、流级 retry 的三组语义与查询出口 |
| 范围 | 做：event 回退/清空、id 持久/清空/NUL、retry 纯数字与 0 值、`has_retry`/`retry_hint` 拆分；不做：重连算法 |
| 交付物 | `sse/sse.h.ct` 字段语义；`s3_fields`、`s3_retry_zero`、`s3_state` 夹具 |
| 依赖 | PH-02 |
| 规范版本 | 1.10.0 |
| version-minor | 3 |
| 已知风险 | `retry` 溢出/前导零；id 的 dispatch 时刻取值；`retry: 0` 与「未设置」的区分 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | `s3_fields` 夹具（先红） | `bash test/run.sh s3_fields`（红） | `be0d62f` | 是 |
| T2 | 字段语义实现 | `bash test/run.sh s3_fields` | `b4fa47e` | 是 |
| T3 | `s3_state` 覆盖缺口夹具（第 14 题补） | `bash test/run.sh s3_state` | 本次提交 `test(sse): S14 覆盖缺口夹具` | 是 |

> 第 4 题的 `has_retry()`/`retry_hint()` 拆分是 PH-08 窗口内的 `0.8.1` fix，
> 见 [PH-08](../PH-08/card.md)；本卡只锁字段语义。

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | event 缺省/空值 → message；dispatch 后清空 | `bash test/run.sh s3_fields` |
| E-2 | id 持久、空值清除、NUL 忽略 | 同上 |
| E-3 | retry 只收纯数字；`+5`/`-1`/`3x`/空值忽略 | 同上 |
| E-4 | dispatch 时刻取 id；retry 溢出保留前值、`007`→7；finish 保留 id/retry；reset 保留 lastEventId | `bash test/run.sh s3_state` |
| E-5 | `retry: 0` 为已设置，跨事件与 reset 保持 | `bash test/run.sh s3_retry_zero` |
| E-6 | 任务清单每项可独立验收（6.6 T-6） | 三条 `verify` 分别单跑 |

## 4 回滚

`git revert b4fa47e` 后 `s3_fields` 红；T1 可单独 revert。`s3_state` 为纯增量，
revert 本次提交即移除。

## 5 顺序与红证

- 红：`be0d62f test(sse): S3 红`（0.2.0）。
- 绿：`b4fa47e feat(sse): S3 字段语义`（0.3.0）。
- `s3_state` 首跑即绿，按「先实现、后补锁」登记（[S14](../../reviews/S14-coverage.md) §4.1）。

## 6 收口记录

- 2026-11-15：`s3_fields`、`s3_retry_zero`、`s3_state` 均 `ok`；版本 0.3.0；仅本地提交。

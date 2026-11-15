# PH-06：`sse_event_copy` / `sse_event_free` 与 EOF 清理

> 编号 `PH-06`；目录 `docs/phases/PH-06/`；`version-minor` 6；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**；顺序见 §5。
> 依据：S0 card W10、M-1；B-3、B-11。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 提供跨回调保留事件的唯一正确出口，并把 `finish()` 固定为 EOF 丢弃 |
| 范围 | 做：深拷贝/释放、data 按长度拷贝（含 NUL）、EOF 丢弃 pending；不做：引用计数/GC |
| 交付物 | `sse/sse.h.ct` copy/free 与 finish；`s6_copy`、`s6_finish_eof`、`s6_borrow_uaf` 夹具 |
| 依赖 | PH-05 |
| 规范版本 | 1.10.0 |
| version-minor | 6 |
| 已知风险 | copy 的 OOM 清理；`sse_event_free` 误用于 borrow 视图；finish 不得分发残留 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | `s6_copy` 夹具（先红） | `bash test/run.sh s6_copy`（红） | `e5549b6` | 是 |
| T2 | copy/free 实现 | `ASAN=1 bash test/run.sh s6_copy` | `c1868a3` | 是 |
| T3 | `finish` EOF 丢弃修正 | `bash test/run.sh s6_finish_eof` | `d0e93bf` | 是 |
| T4 | 借用负例（ASan UAF） | `ASAN=1 bash test/run.sh s6_borrow_uaf` | `6f95cf5`（PH-07 窗口） | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | 副本在后续 feed 与 `delete parser` 后内容不变；含 NUL 的 data 按 `data_len` 保留 | `ASAN=1 bash test/run.sh s6_copy` |
| E-2 | `finish` 丢弃 pending 半行与 data，0 事件；之后 `feed`=-1 | `bash test/run.sh s6_finish_eof` |
| E-3 | 未 copy 的视图在 `delete` 后读取，ASan 报 heap-use-after-free 并 abort | `ASAN=1 bash test/run.sh s6_borrow_uaf` |
| E-4 | 任务清单每项可独立验收（6.6 T-6） | 四条 `verify` 分别单跑 |

## 4 回滚

`git revert c1868a3` 后 `s6_copy` 红；`git revert d0e93bf` 后 EOF 行为回到旧口径
（`s6_finish_eof` 红）。T4 是负例，单独 revert 不影响实现。

## 5 顺序与红证

- 红：`e5549b6 test(sse): S6 红`（0.4.0）。
- 绿：`c1868a3 feat(sse): S6 拷贝出口`（0.6.0）。
- 修正：`d0e93bf fix(sse): finish 丢弃残留缓冲`，版本仍 0.6.0。
  **版本偏离登记**：按现行 6.7，phase 内 fix 应 +PATCH；历史提交未动版本，不追溯改写。
- T4 的负例在本片实现后补（`6f95cf5`），首跑即按预期 abort；无独立红提交。

## 6 收口记录

- 2026-11-15：`s6_copy`（ASan）、`s6_finish_eof`、`s6_borrow_uaf`（预期 abort）均 `ok`；
  版本 0.6.0；仅本地提交。

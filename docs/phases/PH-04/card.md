# PH-04：跨分片行结束与 BOM

> 编号 `PH-04`；目录 `docs/phases/PH-04/`；`version-minor` 4；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**；顺序见 §5。
> 依据：S0 card W1、W9；[S14](../../reviews/S14-coverage.md)。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 任意切分的字节流与整块输入产生同一事件序列，且只剥流首 BOM |
| 范围 | 做：CRLF/CR/LF、CRLF 跨 feed、BOM 整块/跨分片/回放、reset 后重新武装；不做：编码转换 |
| 交付物 | `sse/sse.h.ct` 分片与 BOM 逻辑；`s4_chunk`、`s4_bom_edge` 夹具 |
| 依赖 | PH-03 |
| 规范版本 | 1.10.0 |
| version-minor | 4 |
| 已知风险 | BOM 三字节判定跨块；非 BOM 首字节回放；流中 BOM 不得剥 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | `s4_chunk` 夹具（先红） | `bash test/run.sh s4_chunk`（红） | `01c8aac` | 是 |
| T2 | 分片与 BOM 实现 | `bash test/run.sh s4_chunk` | `7c152b2` | 是 |
| T3 | `s4_bom_edge` 覆盖缺口夹具（第 14 题补） | `bash test/run.sh s4_bom_edge` | 本次提交 `test(sse): S14 覆盖缺口夹具` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | 逐字节 feed 与整块 feed 的事件序列一致 | `bash test/run.sh s4_chunk` |
| E-2 | CRLF / 单 CR / 单 LF 各出 1 事件；CRLF 跨块不多计 | 同上 |
| E-3 | BOM 整块/跨 3 分片只剥一次；非 BOM 首字节回放 | 同上 |
| E-4 | 中段 BOM 字节不剥，按未知字段忽略 | `bash test/run.sh s4_bom_edge` |
| E-5 | 任务清单每项可独立验收（6.6 T-6） | 三条 `verify` 分别单跑 |

## 4 回滚

`git revert 7c152b2` 后 `s4_chunk` 红；T1 可单独 revert。`s4_bom_edge` 为纯增量。

## 5 顺序与红证

- 红：`01c8aac test(sse): S4 红`（0.3.0）。
- 绿：`7c152b2 feat(sse): S4 分片与 BOM`（0.4.0）。
- `s4_bom_edge` 首跑即绿，按「先实现、后补锁」登记（[S14](../../reviews/S14-coverage.md) §4.1）。

## 6 收口记录

- 2026-11-15：`s4_chunk`、`s4_bom_edge` 均 `ok`；版本 0.4.0；仅本地提交。

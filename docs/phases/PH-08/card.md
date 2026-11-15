# PH-08：值返回注册表（含 0.8.1 retry 修正）

> 编号 `PH-08`；目录 `docs/phases/PH-08/`；`version-minor` 8；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**；顺序见 §5。
> 依据：第 3、4 题裁定；[S8-int-host](../../reviews/S8-int-host.md)。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 注册表方法按值返回宿主，调用方能一行落变量；并补齐 retry 查询的拆分 |
| 范围 | 做：struct 宿主、`init`/`reg` 返回宿主、`make` 查表、错误码 1/2/3；不做：int 宿主、动态扩容、链式 |
| 交付物 | `sse/sse.h.ct` 注册表；`s8_registry` 夹具；retry 查询拆分 |
| 依赖 | PH-07 |
| 规范版本 | 1.10.0 |
| version-minor | 8（含 PATCH 0.8.1） |
| 已知风险 | 方法结果不能作下一跳接收者；重键必须首条生效；name 是借用 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | `s8_registry` 夹具（先红） | `bash test/run.sh s8_registry`（红） | `874a1ed` | 是 |
| T2 | 注册表实现 | `bash test/run.sh s8_registry` | `ffaddc6` | 是 |
| T3 | 内置类型宿主能力表与契约 | 文档核对 | `2cc6b27` | 是 |
| T4 | retry 查询拆分红 | `bash test/run.sh s3_retry_zero`（红） | `07e8731` | 是 |
| T5 | `has_retry`/`retry_hint` 实现（0.8.1） | `bash test/run.sh s3_retry_zero` | `4819fe6` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | `SseRegistry reg = base.reg(...)` 与 `reg.make(...)` 可编译运行 | `bash test/run.sh s8_registry` |
| E-2 | 缺失 `err=1`；重键 `err=2` 且首条生效；满 `err=3`；命中 `err=0` | 同上（`dup_err=2 size=2` 直接断言） |
| E-3 | `retry: 0` → `has_retry=1`、`hint=0`，跨事件与 reset 保持 | `bash test/run.sh s3_retry_zero` |
| E-4 | 任务清单每项可独立验收（6.6 T-6） | 五条 `verify` 分别单跑 |

## 4 回滚

`git revert ffaddc6` 后 `s8_registry` 红；`git revert 4819fe6` 后 retry 查询回到拆分前的
形态（`s3_retry_zero` 红）。T3 为文档，可单独 revert。

## 5 顺序与红证

- 红：`874a1ed test(sse): S8 红`（0.7.0）。
- 绿：`ffaddc6 feat(sse): S8 值返回注册表`（0.8.0）。
- 修正：`07e8731` 红 → `4819fe6` 绿，版本 `0.8.1`（第 4 题）。
  这是本仓库唯一一次显式 PATCH；与 6.7 V-3 一致。

## 6 收口记录

- 2026-11-15：`s8_registry`、`s3_retry_zero` 均 `ok`；版本 0.8.0 → 0.8.1；仅本地提交。

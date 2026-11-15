# PH-01：类型 / 构造 / 查询 / Drop 骨架

> 编号 `PH-01`；目录 `docs/phases/PH-01/`；`version-minor` 1；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**。实现与红证发生在卡之前，顺序见 §5。
> 依据：[S0 card](../S0/card.md) §3、[评估](../../reviews/evaluation.md) 第 2 题。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 建立可构造、可查询、可销毁的 `SseParser` 骨架，让后续片有公共出口 |
| 范围 | 做：公开类型、构造/销毁、错误查询、finish 标志骨架；不做：解析、字段、分片 |
| 交付物 | `sse/sse.h.ct`；`test/run.sh`；`test/fixtures/s1_construct.ct` 与 `.expected.out` |
| 依赖 | S0 契约冻结（`5ac6210`）；CT v0.53.0 |
| 规范版本 | 1.10.0 |
| version-minor | 1 |
| 已知风险 | 带 namespace 单元不能用静态固有方法；`delete` 的最终 free 绕过漏斗（后续片处理） |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | `s1_construct` 夹具（先红） | `bash test/run.sh s1_construct`（红） | `2126924` | 是 |
| T2 | 骨架实现 | `bash test/run.sh s1_construct` | `c5cb267` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | 构造成功；`has_error()==0`、`error_msg()==0`、`last_event_id()==0`、`has_retry()==0` | `bash test/run.sh s1_construct` |
| E-2 | `finish()` 返回 0；第二次返回 -1；之后 `feed` 返回 -1 且文本 `parser finished` | 同上 |
| E-3 | `reset()` 清错误与 finish 状态 | 同上 |
| E-4 | 构建零警告（`-Wall -Wextra -Werror`） | `test/run.sh` 的 `warning:` 检查 |
| E-5 | 任务清单每项可独立验收（6.6 T-6） | 两条 `verify` 分别单跑 |

## 4 回滚

`git revert c5cb267` 后 `sse/` 不存在，后续片的构建全部失败；T1 夹具可独立 revert
`2126924`。回滚不影响文档层。

## 5 顺序与红证（如实登记）

- 先有红：`2126924 test(sse): S1 红`（当时 `ct.pkg` 尚未创建，构建失败即红）。
- 后有绿：`c5cb267 feat(sse): S1 骨架与构造`，版本 `0.1.0`。
- 本卡是**实现后补的**回溯卡；不推倒已绿实现，也不把红证补写成「卡先行」。

## 6 收口记录

- 2026-11-15：`bash test/run.sh s1_construct` → `ok s1_construct`；版本 0.1.0；仅本地提交。

# PH-07：README、示例与集成形态

> 编号 `PH-07`；目录 `docs/phases/PH-07/`；`version-minor` 7；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**；顺序见 §5。
> 依据：S0 card M-1、E-9；B-12。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 让调用方能按文档正确使用解析器，并展示 chunk 回调驱动 `feed` 的形态 |
| 范围 | 做：README 的 API/所有权/错误表、传输回调示例、W2/W5/W10 补测；不做：新解析行为 |
| 交付物 | `README.md`；`test/fixtures/s7_integration.ct` 与期望输出；W2/W5/W10 补测 |
| 依赖 | PH-06 |
| 规范版本 | 1.10.0 |
| version-minor | 7 |
| 已知风险 | 文档与实现漂移；示例不得暗示闭包可用；借用的生命周期必须写清 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | W2/W5/W10 补测与借用负例 | `bash test/run.sh s2_basic`；`s6_finish_eof`；`ASAN=1 bash test/run.sh s6_borrow_uaf` | `6f95cf5` | 是 |
| T2 | README + `s7_integration` | `bash test/run.sh s7_integration` | `0d052e0` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | README 含公开 API 表、F-1–F-3、W1–W10、M-1 七条所有权、X-1 错误文本 | 人工逐条核对 |
| E-2 | 传输回调示例可构建运行；`feed<0` 时通知传输层停止 | `bash test/run.sh s7_integration` |
| E-3 | 注释行、空 data、EOF 丢弃三条补测存在 | `s7_integration`、`s2_basic`、`s6_finish_eof` |
| E-4 | 任务清单每项可独立验收（6.6 T-6） | 两条 `verify` 分别单跑 |

## 4 回滚

`git revert 0d052e0` 后 README 与示例回到 PH-06 状态，实现不受影响；
`git revert 6f95cf5` 移除补测与借用负例。

## 5 顺序与红证

- 本片没有独立红提交：T1 是补测，T2 是文档+示例。按 T-7 的红证要求，这里属于
  「测试随实现走」的例外，如实登记，不补造红证。
- 版本 `0.7.0` 随 T2 移动。

## 6 收口记录

- 2026-11-15：`s7_integration` `ok`；README 与代码一致；版本 0.7.0；仅本地提交。

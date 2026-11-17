# PH-14：ct-http 若含 SSE 逻辑的下沉跟进

> 编号 `PH-14`；目录 `docs/phases/PH-14/`；`version-minor` 14；规范版本 1.10.0。
> 状态：**已复核（ct-http v0.2.1 无工作项；0.14.0 不交付）**。
> 依据：第 16 题裁定；[S16](../../reviews/S16-dependency-direction.md) §2–§3。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 若 ct-http 后续版本掺入 SSE 语义，把它识别出来并建议下沉到 ct-sse，不在本包改对方代码 |
| 范围 | 做：重新审计、逐条归类、给 ct-http 的 issue/提案；不做：修改 ct-http、把 SSE 判断留在传输层 |
| 交付物 | `docs/reviews/S16-dependency-direction.md` 增补；ct-http issue/提案链接（若触发） |
| 依赖 | PH-11；ct-http 新版本 |
| 规范版本 | 1.10.0 |
| version-minor | 14 |
| 已知风险 | 把普通 HTTP 注释误判成 SSE；在 ct-http 未变更时制造无意义改动 |

## 2 任务清单

| id | 交付物 | 验收命令 | effort | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- | --- |
| T1 | ct-http 新版本审计（no-test: 纯复核记录） | `grep -rniE "event-stream" http/`；完整模式见 S16 §2.5 | S | 计划：`docs(sse): PH-14 T1 审计` | 是 |
| T2 | 下沉建议（仅报告；无项时不制造改动） | issue/提案链接存在，或明确写「无工作项」 | S | 计划：`docs(sse): PH-14 T2 建议` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | grep 结果逐条归类，无未归类的 SSE 语义 | 审计表 |
| E-2 | 若存在 SSE 语义：ct-http issue/提案已提交且有链接；本包未改对方文件 | `git status` 不含 ct-http 路径 |
| E-3 | 若不存在：明确写「无工作项」，不制造改动 | 审计结论 |
| E-4 | 任务清单每项可独立验收（6.6 T-6） | 两条 `verify` 分别单跑 |

## 4 回滚

仅文档；回滚即删除增补记录。

## 5 触发与当前结论

- 触发条件：ct-http 发布版出现 SSE 解析、事件分发、`text/event-stream` 判断或
  `Last-Event-ID` 处理。
- 当前结论（ct-http v0.2.1，commit `1121bbc`；2026-11-17 复核）：**0 处 SSE 语义**，
  本片无工作项。`grep` 唯一命中是 `http.shim.c` 的函数指针分派注释；证据见
  [S16](../../reviews/S16-dependency-direction.md) §2.5。不为了凑片去改 ct-http 或本包。

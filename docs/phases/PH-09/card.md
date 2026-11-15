# PH-09：分配器注入、OOM、计数、finish 可观测性、I-1

> 编号 `PH-09`；目录 `docs/phases/PH-09/`；`version-minor` 9；规范版本 1.10.0。
> 状态：**已收口（回溯卡）**；顺序见 §5。
> 依据：第 6/7/8/12/13 题裁定；[S9](../../reviews/S9-allocator.md)、[S13](../../reviews/S13-http-integration.md)。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 让分配失败可被测、可计数、可证明；用真实 ct-http 跑通字节到事件；finish 清理只用两类证据 |
| 范围 | 做：分配漏斗、运行期失败注入、OOM 四处、计数三切法、finish 计数快照+行为断言、真实对接门禁；不做：LSan、真实 TCP 穷举、只读视察接口 |
| 交付物 | `sse/sse.h.ct`（漏斗/`sse_parser_free`）；`s9_oom`、`s9_alloc_count`、`s9_finish_clean`、`s9_error_codes`；`i1_http_stream` + `test/integration.sh`；`S9-allocator.md`、`S13-http-integration.md` |
| 依赖 | PH-08；ct-http 0.1.0 发布 tag |
| 规范版本 | 1.10.0 |
| version-minor | 9 |
| 已知风险 | 函数指针间接可能顶到 `MAX_CALLS`；`delete` 的最终 free 绕过漏斗；集成门禁依赖外部取包 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | 分配器/OOM/计数夹具（先红） | `bash test/run.sh s9_oom`（红） | `3ce6444` | 是 |
| T2 | 漏斗、`sse_parser_free`、计数实现 | `bash test/run.sh s9_oom`；`s9_alloc_count` | `990432d` | 是 |
| T3 | finish 清理双证据夹具 | `bash test/run.sh s9_finish_clean` | `4c92cb1` | 是 |
| T4 | I-1 真实对接 + 独立集成门禁 | `bash test/integration.sh` | `e00f9c6` | 是 |
| T5 | 错误码表夹具（第 14 题补） | `bash test/run.sh s9_error_codes` | 本次提交 `test(sse): S14 覆盖缺口夹具` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | 四处 OOM（parser/行缓冲/data 缓冲/copy）均返回 -1 或 0、码 2、文本 `out of memory` | `bash test/run.sh s9_oom` |
| E-2 | 整块/逐字节/伪随机三切法 `allocs==frees && live==0` | `bash test/run.sh s9_alloc_count` |
| E-3 | `finish` 前后分配计数增量为 0；销毁后归零；行为上不吐旧数据 | `bash test/run.sh s9_finish_clean` |
| E-4 | 错误码 0/1/2/3/4/5 逐条断言 | `bash test/run.sh s9_error_codes` |
| E-5 | 真实 ct-http 发布版 chunk 驱动 `feed`，覆盖 BOM 分片、data 跨 chunk、多行 data、id/retry、空 id、空行、EOF | `bash test/integration.sh`（0 通过；2 前置缺失） |
| E-6 | 任务清单每项可独立验收（6.6 T-6） | 五条 `verify` 分别单跑 |

## 4 回滚

`git revert 990432d` 后 OOM/计数夹具红，`sse_parser_free` 消失；`git revert 4c92cb1`
移除 finish 双证据；`git revert e00f9c6` 移除 I-1 与集成门禁。四者互不依赖。

## 5 顺序与红证

- 红：`3ce6444`（0.8.1）；绿：`990432d feat(sse): S9 分配器注入与计数`（0.9.0）。
- T3、T4、T5 都是测试/门禁增量，无独立红提交；T5 首跑即绿（实现已正确），
  按「先实现、后补锁」登记（[S14](../../reviews/S14-coverage.md) §4.1）。
- `MAX_CALLS` 实测余量 978/1024，未触发停机条件（S9 §2）。

## 6 收口记录

- 2026-11-15：`s9_oom`、`s9_alloc_count`、`s9_finish_clean`、`s9_error_codes` 均 `ok`；
  I-1 当次跑通（ct-http 0.1.0）。版本 0.9.0；仅本地提交。
- 遗留：2026-11-15 首次复跑 `test/integration.sh` 在 `ct get` 的 git fetch 阶段失败，
  随后同一命令通过（`ok i1_http_stream`）；首次失败记为 G-5
  （[evaluation](../../reviews/evaluation.md) §5），不改变本片结论。

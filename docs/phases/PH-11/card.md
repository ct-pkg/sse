# PH-11：文档与示例收尾

> 编号 `PH-11`；目录 `docs/phases/PH-11/`；`version-minor` 11；规范版本 1.10.0。
> 状态：**未开工**（下一张卡）。
> 依据：[需求定稿](../../requirements.md)、[roadmap](../../planning/roadmap.md) §3.1。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 让文档、示例与 0.10.0 的公开面完全对齐，后续片不再在过期文档上施工 |
| 范围 | 做：文档索引、链接检查、README 与生成头对齐、三个可运行示例；不做：新增解析行为、不改 `sse/` 的功能 |
| 交付物 | `docs/README.md`；`tools/check_links.py`；`docs/snippets/`（registry/copy/error-codes 三例及期望输出）；`README.md` 修订 |
| 依赖 | PH-10 |
| 规范版本 | 1.10.0 |
| version-minor | 11 |
| 已知风险 | 文档链接跨目录失效；示例输出与真实运行不一致；README 漏列符号 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | 文档索引 + 链接检查脚本 | `python3 tools/check_links.py docs README.md` | 计划：`docs(sse): PH-11 T1 文档索引与链接检查` | 是 |
| T2 | README 公开面与所有权对齐 | `python3 tools/check_api.py`（符号集合比对） | 计划：`docs(sse): PH-11 T2 README 对齐` | 是 |
| T3 | 三个可运行示例 | `bash test/run.sh ex_registry`；`ex_copy`；`ex_error_codes` | 计划：`test(sse): PH-11 T3 示例` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | 所有相对链接目标存在，缺失数为 0 | `python3 tools/check_links.py docs README.md` 退出 0 |
| E-2 | README 的公开符号表与 `nm` 导出的 `sse_` 符号集合一致 | `python3 tools/check_api.py` 退出 0 |
| E-3 | 三个示例均构建、运行、diff 通过 | 三条 `test/run.sh` 退出 0 |
| E-4 | 构建零警告（沿用现有门禁） | `test/run.sh` 的 `warning:` 检查 |
| E-5 | 任务清单每项可独立验收（6.6 T-6） | 三条 `verify` 分别单跑 |

## 4 回滚

删除 `docs/README.md`、`tools/check_links.py`、`tools/check_api.py`、`docs/snippets/`，
`README.md` 回到 0.10.0 版本；`sse/` 与既有夹具不受影响。

## 5 冻结与开工

- 退出判据与任务清单在本卡首次实现提交后冻结；中途只新增 PH-12，不改本卡。
- 开工前先跑一遍现有全量门禁，确认 0.10.0 基线绿；集成门禁的 `ct get` 失败记为遗留，
  不阻塞本卡（本卡不依赖外部包）。

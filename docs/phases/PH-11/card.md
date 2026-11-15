# PH-11：文档与示例收尾

> 编号 `PH-11`；目录 `docs/phases/PH-11/`；`version-minor` 11；规范版本 1.10.0。
> 状态：**已收口**（PH-12 未开）。
> 依据：[需求定稿](../../requirements.md)、[roadmap](../../planning/roadmap.md) §3.1。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 让文档、示例与 0.10.0 的公开面完全对齐，后续片不再在过期文档上施工 |
| 范围 | 做：文档索引、链接检查、README 与生成头对齐、三个可运行示例；不做：新增解析行为、不改 `sse/` 的功能 |
| 交付物 | `docs/README.md`（索引）；`tools/check_links.py`；`tools/check_api.py` + `tools/api_surface.txt`；`test/fixtures/ex_registry.ct`、`ex_copy.ct`、`ex_error_codes.ct` 及期望输出；`README.md` 修订 |
| 依赖 | PH-10 |
| 规范版本 | 1.10.0 |
| version-minor | 11 |
| 已知风险 | 文档链接跨目录失效；示例输出与真实运行不一致；README 漏列符号 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | 文档索引 + 链接检查脚本 | `python3 tools/check_links.py` | `docs(sse): PH-11 T1 文档索引与链接检查` | 是 |
| T2 | 公开面清单 + README 对齐检查 | `python3 tools/check_api.py` | `docs(sse): PH-11 T2 公开面对齐` | 是 |
| T3 | 三个可运行示例（放 `test/fixtures/`，复用 `run.sh`） | `bash test/run.sh ex_registry`；`ex_copy`；`ex_error_codes` | `test(sse): PH-11 T3 示例` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | 所有相对链接目标存在，且 `docs/` 下每个 Markdown 都能从索引直达；缺失数为 0 | `python3 tools/check_links.py` 退出 0 |
| E-2 | 生成头导出的函数符号与 `tools/api_surface.txt` 完全一致，且每个公开名在 README 出现 | `python3 tools/check_api.py` 退出 0 |
| E-3 | 三个示例均构建、运行、diff 通过 | 三条 `test/run.sh` 退出 0 |
| E-4 | 构建零警告（沿用现有门禁） | `test/run.sh` 的 `warning:` 检查 |
| E-5 | 任务清单每项可独立验收（6.6 T-6） | 三条 `verify` 分别单跑 |

## 4 回滚

删除 `docs/README.md`、`tools/check_links.py`、`tools/check_api.py`、`tools/api_surface.txt`、
`test/fixtures/ex_*.ct` 与对应期望输出，`README.md` 回到 0.10.0 版本；`sse/` 与既有夹具不受影响。

## 5 红证计划与冻结

- T1：先写检查器、后写索引。首跑因 `docs/README.md` 不存在而红，补索引后转绿。
- T2：先写检查器、后写清单。首跑因 `tools/api_surface.txt` 不存在而红，补清单/README 后转绿。
- T3：`ex_registry` 首跑真红（见 §6）；`ex_copy`/`ex_error_codes` 是纯增量、使用已绿 API，
  首跑即绿，按「先实现、后补锁」登记，不造假红。
- 退出判据与任务清单在首次实现提交后冻结；本卡施工期间不开 PH-12。

## 6 收口记录

- T1 红：`files=33 links=126 broken=14 unreachable=1`（`docs/README.md is missing`；
  S0 卡的 `../reviews/` 少一层）。修复 S0 卡链接、补索引后：
  `files=34 links=159 broken=0 unreachable=0`。
- T2 红：`MISSING tools/api_surface.txt`。补清单后：
  `header=24 surface=24 extra=0 missing=0 undocumented=0`。
- T3 红：`ex_registry` 首跑 `error: use of an undeclared variable`；改限定名后又报
  `no variable of that name in that namespace`。确认 CT 不能把命名空间函数直接当值传，
  改为本地 wrapper `make_parser`，README 的注册表示例同步修正。
  `ex_copy`/`ex_error_codes` 首跑即绿。
- 判据：E-1/E-2 退出 0；E-3 三条示例 `ok`；E-4 零警告；E-5 三条 `verify` 分别单跑通过。
- 版本：`0.10.0` → `0.11.0`。遗留：无（PH-12 未开）。

# Changelog

版本号规则见 `AGENTS.md` 6.7：MINOR 与 phase 对应，PATCH 与 fix 对应。
0.1.0–0.10.0 的逐片记录见 `docs/phases/PH-01…PH-10/card.md`。

## [0.12.0] - 2026-11-17

PH-12 收口（无公开 API 改动）：

- `test/run.sh` 删除 `grep -q 'warning:'` 文本匹配；构建警告由
  `-Wall -Wextra -Werror` 升级为错误，以 `ct build` 退出码判定。
- 新增 `test/gates/g12_warning.sh` 负例自检：注入未使用参数必须使构建失败。
- 新增 `docs/reviews/diagnostics-format.md`：记录 CT v0.63.0 的
  `--diagnostics=json` 探针、C 警告的级别升级路径与限制。
- 公开面不变：`tools/api_surface.txt` 24 个符号，`check_api.py` 全绿。

## [0.11.0] - 2026-11-15

PH-11 收口：

- 文档索引 `docs/README.md`；`tools/check_links.py` 链接检查。
- `tools/check_api.py` 与 `tools/api_surface.txt`：生成头符号与 README 对齐。
- 三个可运行示例：`ex_registry`、`ex_copy`、`ex_error_codes`。

## [0.8.1] - 2026-11-15

PH-08 窗口内的 fix：

- `retry` 查询拆分为 `has_retry()` + `retry_hint()`；`retry: 0` 是合法已设置值。

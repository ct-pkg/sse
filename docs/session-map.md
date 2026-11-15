# 会话映射

| 日期 | 会话 / 主题 | 产出 |
| --- | --- | --- |
| 2026-11-15 | S0 事实核对与契约冻结（ct v0.53.0） | `docs/reviews/S0-facts.md`、`docs/reviews/S0-battle.md`、`docs/phases/S0/card.md` |
| 2026-11-15 | S1–S6 实施（骨架/闭环/字段/分片/限额/拷贝） | `sse/sse.h.ct`、`test/run.sh`、`test/fixtures/s1_*`…`s6_*` |
| 2026-11-15 | S7 文档与集成示例 | `README.md`、`test/fixtures/s7_integration.*` |
| 2026-11-15 | S8 值返回注册表与内置类型宿主探针 | `sse/sse.h.ct`（SseRegistry）、`test/fixtures/s8_registry.*`、`docs/reviews/S8-int-host.md` |
| 2026-11-15 | S9 分配器注入、OOM 与计数门禁登记 | `sse/sse.h.ct`（alloc/free 漏斗、`sse_parser_free`）、`test/fixtures/s9_*`、`docs/reviews/S9-allocator.md` |
| 2026-11-15 | I-1 ct-http 真实对接（独立集成门禁） | `test/fixtures/i1_http_stream.*`、`test/integration.sh`、`test/integration/i1_server.py`、`docs/reviews/S13-http-integration.md` |
| 2026-11-15 | S10 回调重入拒绝 | `sse/sse.h.ct`（`in_callback`）、`test/fixtures/s10_reentrant.*` |
| 2026-11-15 | 第 14 题：契约细则覆盖表 + 缺口夹具 | `docs/reviews/S14-coverage.md`、`s2_syntax`、`s3_state`、`s4_bom_edge`、`s9_error_codes`、`s10_reentrant_state`、`s8_registry` 补强 |
| 2026-11-15 | 第 16 题：依赖方向与 ct-http 审计 | `docs/reviews/S16-dependency-direction.md`、README 依赖方向 |
| 2026-11-15 | 五层产物收口 | `docs/reviews/evaluation.md`、`docs/requirements.md`、`docs/planning/roadmap.md`、`docs/phases/PH-01…PH-14/card.md` |
| 2026-11-15 | PH-11 文档与示例收尾 | `docs/README.md`、`tools/check_links.py`、`tools/check_api.py`、`tools/api_surface.txt`、`test/fixtures/ex_*.ct`、README 注册表示例修正 |

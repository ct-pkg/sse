# PH-12：诊断格式落地后替换门禁读文本

> 编号 `PH-12`；目录 `docs/phases/PH-12/`；`version-minor` 12；规范版本 1.15.0。
> 状态：**已收口**（0.12.0；PH-13 未开）。
> 依据：第 11 题裁定；[S0-closeout](../../reviews/S0-closeout.md) D-6；
> [diagnostics-format](../../reviews/diagnostics-format.md)。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 把“构建警告”从 `warning:` 文本匹配换成按诊断级别判定，消除临时门禁 |
| 范围 | 做：`test/run.sh` 的警告判定、负例夹具、诊断格式记录；不做：在 C 诊断仍为文本时自造解析器，不改 `sse/` |
| 交付物 | `test/gates/g12_warning.sh`；`test/run.sh` 修订；`docs/reviews/diagnostics-format.md` |
| 依赖 | PH-11；CT v0.63.0 的 `--diagnostics=json`；`-Werror` 级别升级 |
| 规范版本 | 1.15.0 |
| version-minor | 12 |
| 已知风险 | 把 `warning:` 换成另一种文本匹配，等于没换；CT L0 将来输出非致命警告时退出码仍为 0 |

## 2 任务清单

| id | deliverable | verify | effort | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- | --- |
| T1 | `test/gates/g12_warning.sh`：断言门禁不再用文本匹配、注入未使用参数必须失败 | `bash test/gates/g12_warning.sh`（实现前红、实现后绿） | S | `test(sse): PH-12 T1 诊断级别门禁红` | 是 |
| T2 | `test/run.sh`：删除 `grep -q 'warning:'`，改由 `-Werror` + 构建退出码判定 | `bash test/run.sh s1_construct`；`bash test/gates/g12_warning.sh` | S | `fix(sse): PH-12 T2 构建警告按级别判定` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | `test/run.sh` 中 `grep -q 'warning:'` 的计数为 0 | `grep -c "grep -q 'warning:'" test/run.sh` 输出 0 |
| E-2 | 注入一个未使用参数：门禁退出 1，原因来自诊断级别 | `bash test/gates/g12_warning.sh` 的负例构建退出码 1 |
| E-3 | 无警告构建下全量夹具退出 0 | roadmap §6 全量命令，逐条 `ok` |
| E-4 | 任务清单每项可独立验收（6.6 T-6） | T1/T2 的 `verify` 分别单跑 |

## 4 回滚

删除 `test/gates/g12_warning.sh`；`test/run.sh` 恢复到 0.11.0 的文本匹配段；`docs/reviews/diagnostics-format.md`
保留为探针记录。`sse/` 与既有夹具不受影响。

## 5 红证计划与冻结

- T1 先落：`test/gates/g12_warning.sh` 在实现前检查到 `test/run.sh` 仍含
  `grep -q 'warning:'`，退出 1；红证写入 §6。
- T2 后落：删除文本匹配后同一脚本转绿；注入未使用参数的负例仍退出 1。
- T-7 例外：`docs/reviews/diagnostics-format.md` 是探针记录，不含行为改动；随台账提交。
- 退出判据与任务清单在 T1 提交后冻结；本卡施工期间不开 PH-13/PH-14。

## 6 收口记录

- T1 红：`baseline: 584c781`（test 提交的父提交；红跑在 771c8da，.gitignore 不影响该断言）；`bash test/gates/g12_warning.sh` →
  `FAIL g12_warning: test/run.sh still matches 'warning:' text`，退出码 1。
- T2 绿：`bash test/gates/g12_warning.sh` → `ok g12_warning (level-based, exit=1)`；
  `bash test/run.sh s1_construct` → `ok s1_construct`。
- E-3：全量 23 条夹具与示例逐条 `ok`；`bash test/gates/g12_warning.sh` 绿。
- 版本：`0.11.0` → `0.12.0`；`ct.pkg#version` 与 README `Package version:` 同提交对齐。
- tag：收口提交后建 annotated `v0.12.0`；分支未推送，按 V-7 ④ 不推 tag。
- 遗留：无（PH-13 保持环境阻塞，PH-14 无工作项）。

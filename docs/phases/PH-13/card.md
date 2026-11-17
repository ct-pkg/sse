# PH-13：Linux CI 补 LeakSanitizer

> 编号 `PH-13`；目录 `docs/phases/PH-13/`；`version-minor` 13；规范版本 1.10.0。
> 状态：**阻塞（CI 环境）**。
> 依据：第 8 题裁定；[S9-allocator](../../reviews/S9-allocator.md) §5.1。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 补上“退出时仍可达内存”的检查，区分「整块缓冲漏释放已验证」与「泄漏已验」 |
| 范围 | 做：Linux runner 上的 `detect_leaks=1` 全量运行、CI 配置、记录；不做：用计数器替代 LSan |
| 交付物 | CI 配置；`docs/reviews/lsan-linux.md`（命令与原始输出） |
| 依赖 | PH-11；可运行 CT v0.63.0 的 Linux runner |
| 规范版本 | 1.10.0 |
| version-minor | 13 |
| 已知风险 | runner 缺 CT 或 libcurl；LSan 与 ASan 版本不匹配；把平台差异误判成泄漏 |

## 2 任务清单

| id | 交付物 | 验收命令 | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- |
| T1 | Linux runner 上的全量 ASan+LSan 运行 | `ASAN_OPTIONS=detect_leaks=1 bash test/run.sh <全部>` | 计划：`ci(sse): PH-13 T1 LSan` | 是 |
| T2 | LSan 运行记录 | 原始日志与退出码 | 计划：`docs(sse): PH-13 T2 LSan 记录` | 是 |

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | Linux 上全量夹具退出 0，日志无 `LeakSanitizer` 报告 | CI 日志 + 退出码 |
| E-2 | macOS 上同一命令仍退出 0（不回归） | 本地全量命令（roadmap §6） |
| E-3 | 文档明确区分 LSan 结论与计数器结论 | `lsan-linux.md` 原文 |
| E-4 | 任务清单每项可独立验收（6.6 T-6） | 两条 `verify` 分别单跑 |

## 4 回滚

移除 CI 配置与记录文档；本地门禁与既有夹具不受影响。

## 5 阻塞条件

- 没有 Linux runner 或 runner 不能运行 CT v0.63.0 时不开工。
- 2026-11-17 复核：本机 `docker` 不存在；`podman machine list` 因
  `~/.config/containers/...` 写入被沙箱拒绝而失败；`colima` 因
  `mkdir /Users/samxx/.colima: operation not permitted` 失败。没有可用 Linux 环境。
  原文见 [planning-audit](../../reviews/planning-audit.md) GAP-2。
- 在解除前，退出可达内存继续登记为环境缺口，不用计数器冒充。

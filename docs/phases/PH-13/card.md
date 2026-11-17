# PH-13：Linux CI 补 LeakSanitizer

> 编号 `PH-13`；目录 `docs/phases/PH-13/`；`version-minor` 13；规范版本 1.15.0。
> 状态：**已收口（0.13.0）**。
> 依据：第 8 题裁定；[S9-allocator](../../reviews/S9-allocator.md) §5.1；
> 运行记录：[lsan-linux](../../reviews/lsan-linux.md)。

## 1 开卡必填

| 字段 | 内容 |
| --- | --- |
| 目标 | 补上“退出时仍可达内存”的检查，区分「整块缓冲漏释放已验证」与「泄漏已验」 |
| 范围 | 做：Linux 上的 `ASAN_OPTIONS=detect_leaks=1` 全量运行、负例对照、macOS 回归、记录；不做：用计数器替代 LSan，不把 Linux 专属变量强加到 macOS |
| 交付物 | `docs/reviews/lsan-linux.md`（命令、原始输出、负例、边界）；不新增 CI 配置文件，原因见 §5 |
| 依赖 | PH-11；可运行 CT 的 Linux runner（实测 podman Ubuntu 24.04 + CT v0.61.1） |
| 规范版本 | 1.15.0 |
| version-minor | 13 |
| 已知风险 | runner 缺 CT 或 libcurl；LSan 与 ASan 版本不匹配；把平台差异误判成泄漏 |

## 2 任务清单

| id | deliverable | verify | effort | 提交 | 可单独回滚 |
| --- | --- | --- | --- | --- | --- |
| T1 | Linux 全量 ASan+LSan 运行与负例对照，写入 `lsan-linux.md` §1–3、§5 | `ASAN_OPTIONS=detect_leaks=1 … bash test/run.sh <全部>`；负例退出 1 且含 `LeakSanitizer` | M | `docs(sse): PH-13 LSan 记录` | 是（纯文档） |
| T2 | macOS ASan 回归段与平台差异说明，写入 `lsan-linux.md` §4 | `ASAN=1 bash test/run.sh <全部>` 退出 0 | S | 同上（同一记录文档） | 是（纯文档） |

两行都属纯运行记录，`no-test: 运行记录本身即证据，无代码改动`；评审在收口记录里签字。

## 3 退出判据

| # | 判据 | 命令/证据 |
| --- | --- | --- |
| E-1 | Linux 上全量夹具退出 0，日志无 `LeakSanitizer` 报告 | [lsan-linux](../../reviews/lsan-linux.md) §2；`grep -c LeakSanitizer` 为 0 |
| E-2 | macOS 上同一批夹具仍退出 0（不回归） | [lsan-linux](../../reviews/lsan-linux.md) §4；macOS 不支持 `detect_leaks`，按同一批夹具的 ASan 配置执行 |
| E-3 | 文档明确区分 LSan 结论与计数器结论 | [lsan-linux](../../reviews/lsan-linux.md) §5 的两行结论 |
| E-4 | 任务清单每项可独立验收（6.6 T-6） | T1/T2 的 `verify` 分别单跑 |

## 4 回滚

删除 `docs/reviews/lsan-linux.md` 与 PH-13 的收口记录；本地门禁与既有夹具不受影响。
版本随下一次收口回退，不单独改版本号。

## 5 交付形态与阻塞解除

- 原计划写 CI 配置；实际没有写。原因：CT 源码仓库不是公开可拉取的 CI 依赖，GitHub
  hosted runner 无法在无凭据的情况下构建 `ct`。本轮用 podman 的 Ubuntu 24.04 容器复现，
  命令与环境写进 [lsan-linux](../../reviews/lsan-linux.md) §1，任何有 Linux runner 的
  环境都可按同一命令重跑。
- 阻塞解除：2026-11-17 用户提供 podman Ubuntu 容器；镜像内无 CT，按本地 `ct-lang`
  源码构建 Linux CT v0.61.1（主机 CT 为 v0.63.0）。容器文件系统与国内核均可用。
- 平台差异：macOS 的 ASan 不支持 `detect_leaks`，强制加该变量会 abort；E-2 只要求
  macOS 不回归，不要求它在 macOS 上产出 LSan 结论。原文见 [lsan-linux](../../reviews/lsan-linux.md) §4。

## 6 收口记录

- E-1：Linux 23 条夹具全绿，`LeakSanitizer` 计数 0；负例（故意泄漏 16 字节）退出 1 且
  出现 `LeakSanitizer: detected memory leaks`，证明 LSan 可触发。
- E-2：macOS 全量 ASan 23 条全绿；强制 `detect_leaks=1` 时平台 abort，按 §5 的口径记录。
- E-3：`lsan-linux.md` §5 把 LSan 结论、计数器结论、未覆盖项分三行写清。
- E-4：T1/T2 的 `verify` 分别单跑。
- 版本：`0.12.0` → `0.13.0`；`ct.pkg` 与 README 同提交对齐；CHANGELOG 增 0.13.0。
- tag：annotated `v0.13.0`；分支未推送，按 V-7 ④ 不推 tag。
- 评审：本仓暂无常驻 REVIEW 对话，本条由本会话按 §3 逐条自检；独立复核待
  GAP-1 补齐（见 [planning-audit](../../reviews/planning-audit.md) GAP-1），不冒充已签字。
- 遗留：PH-14 无工作项；GAP-1 门禁层仍待处置。

# Issue 台账

一个缺陷一个文件：`issues/SSE-<n>.md`。状态词按主规范 5.4：
`open` / `fixed` / `verified` / `reopened` / `rejected` / `deferred` / `wontfix` / `superseded`。
`fixed` 只出现在正文处置段，不写进 `status`。

最小 front-matter：

```yaml
---
id: SSE-1
status: open
evidence: <复现命令或 file:line>
---
```

当前没有未关闭的 Issue；`bash tools/check.sh g6` 对空台账是合法通过，不伪造条目。

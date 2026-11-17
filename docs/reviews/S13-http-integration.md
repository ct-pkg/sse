# I-1：ct-http 真实对接（独立集成门禁）

> 日期：2026-11-15（0.1.0 原始记录）；2026-11-17 补 CT v0.63 / ct-http 0.2.1 复核（§8）。
> 原始环境：ct v0.53.0、ct-http **0.1.0**（release tag `v0.1.0`，commit `b4b7b43`）。
> 夹具：`test/fixtures/i1_http_stream.ct`；门禁：`bash test/integration.sh`。

## 1 结论

真实链路跑通：ct-http 收到 loopback 服务器发来的 chunk，适配器把字节交给
`sse_parser.feed()`，事件回调收到 4 个事件；EOF 时 `finish()` 丢弃 pending data。
**未发现接口不匹配**（回调签名、所有权、终止语义都吻合），因此没有改任何一侧接口。

## 2 实际跑通的命令（原样）

```console
$ ct get https://github.com/ct-pkg/http@0.1.0        # cwd 为临时目录
vendored 1 package(s)

$ ct build test/fixtures/i1_http_stream.ct \
    -I vendor/http -I <ct-sse 仓库根> \
    -o i1_http_stream --outdir build \
    --cflags "-Wall -Wextra -Werror" --ldflags "-lcurl"

$ python3 test/integration/i1_server.py              # 打印 PORT <n>
$ ./i1_http_stream http://127.0.0.1:<n>/sse
```

`-I <ct-sse 仓库根>` 是 ct-sse 仓库根的占位写法（实际是绝对路径，随 checkout 位置变化，
不写死）；`vendor/` 在临时目录里，路径每次运行都不同。门禁脚本按顺序拼这两个 include 根。

## 3 包根前缀：绕法，不是标准写法

`ct get` 后的真实布局：

```text
vendor/http/ct.pkg
vendor/http/http/http.m.ct
vendor/http/http/Types.h.ct
vendor/http/http/http.shim.c
vendor/http/http/http.shim.h
```

- 正确的 include 根是**包根** `-I vendor/http`，import 写 `http::http`。
- 错误写法实测原文：

```text
$ ct build ... -I vendor/http/http ...
ctc: cannot resolve import 'http/http'
```

- 这是**绕法**：`ct install` 的 include-root 计算不读包内布局（ct-http 已提案，
  见其 `docs/proposals/ct-install-include-prefix.md`；本仓库未改 ct-lang / ct-http）。
  CT 修好 `ct install` 后，应改回 `ct install` 打印的标准命令，并删除本节手写的
  `-I` 顺序。

## 4 接口映射（实测）

| ct-http 0.1.0 | ct-sse | 结论 |
| --- | --- | --- |
| `HttpChunkCb(char *data, int len, void *ud)` | `feed(char *data, int len)` | 适配器直接转发；`feed < 0` 时回调返回 1，中止传输 |
| chunk 内存「仅在回调期间借用」 | `feed` 立刻拷贝进 parser 缓冲 | 所有权不冲突 |
| `send_stream(cb, ud)` 返回 `CResponse *` | — | 读 `status/error/total_bytes` 后 `free` |
| 请求工厂 `char * -> post()`；未设 body 时 shim 置 `CURLOPT_HTTPGET=1` | — | 工厂名叫 `post`，线上方法是 **GET**；夹具未设 body，真实链路是 GET。命名歧义作为建议记录，未改 ct-http（[S16](S16-dependency-direction.md) §3） |

## 5 覆盖的链路行为

- BOM 被拆成 3 个 chunk（`ef` / `bb` / `bf`）后仍只剥一次。
- `data` 跨 chunk：`hel` + `lo`、`x` + `yz`。
- 多行 data：`data: a` + `data: b` → `a\nb`。
- `id` / `retry` 跨事件持久；`id:` 空值清除后下一事件不再带 id。
- 空行分发：共 4 个事件。
- 流结束：`data: dropped` 没有结尾空行，`finish()` 后不产生事件；随后 `feed` 返回 -1。
- `bytes=113` 是 ct-http 实际交给回调的响应体字节数。

原始输出（`test/fixtures/i1_http_stream.expected.out`）：

```text
e1 event=message id=7 has_retry=1 retry=2500 len=5 data=[hello]
e2 event=tick id=7 has_retry=1 retry=2500 len=3 data=[a\nb]
e3 event=message id=7 has_retry=1 retry=2500 len=3 data=[xyz]
e4 event=end id=- has_retry=1 retry=2500 len=3 data=[bye]
status=200 err=0 bytes=113 events=4
finish=0
after=-1
```

## 6 门禁形态与依赖

`bash test/integration.sh` 是**独立集成门禁**，不并入 `test/run.sh`；后者对 `i1_*` 直接拒绝并
提示改用集成门禁。

- 退出码：0 通过、1 失败、2 被外部前置条件阻塞。
- blocked（退出 2）：没有 `ct` / `git` / `python3` / C 编译器 / libcurl 头文件。
- fail（退出 1）：`ct get` 拉不到（网络、git、tag 缺失）、构建失败（`-Werror` 把警告升级为
  错误）、服务器没报端口、夹具非零退出、输出 diff 不符；日志与提示随失败一起打印。
- 每次运行在 `mktemp -d` 里 `ct get`，**不把取包产物提交进仓库**。

## 7 对 ct-http 的建议（仅报告，未实施）

1. 在文档与命名上消除「只能 POST」的歧义：`post()` 是请求工厂，未设 body 时
   `http.shim.c` 置 `CURLOPT_HTTPGET=1`，实际发出 GET。已实测，不需要新增读取入口。
2. 文档明确 chunk 边界不保证与服务器写入对齐；本门禁靠 40ms 间隔让切点落在行内，不是硬保证。
3. 若需要确定性分片，可提供「回调前按脚本切块」的测试 seam；当前只能在服务器侧控制节奏。

ct-http 仓库本次**零改动**：只用 `ct get` 按 tag 取发布版，本地 checkout 的未提交改动未参与。

## 8 2026-11-17 复核：CT v0.63 / ct-http 0.2.1

CT v0.63 的取包形态变了：`ct get` 写包存储与 `ct.lock`，不再创建 `vendor/`；ct-http
0.1.0 的 `ct.pkg` 又没有新编译器要求的 `publisher`。原 §2/§3 的 `-I vendor/http` 绕法
因此失效，保留为 0.1.0 的历史记录。

```console
$ ct get https://github.com/ct-pkg/http@0.2.1
installed 1 package(s)
$ cat ct.lock
ct/http 0.2.1 git https://github.com/ct-pkg/http 1121bbc9c1d24b3933662d475386e419edde768b . sha256:...
$ ct build test/fixtures/i1_http_stream.ct --locked -I <ct-sse 仓库根> \
    -o i1_http_stream --outdir build \
    --cflags "-Wall -Wextra -Werror" --ldflags "-lcurl"
$ bash test/integration.sh
ok i1_http_stream (ct-http 0.2.1, real loopback chunks)
```

`--locked` 自动补包 include 根，门禁不再需要知道存储路径；`test/integration.sh` 已改为
0.2.1 + `--locked`，并删除 `warning:` 文本匹配（`-Werror` 的退出码即级别信号）。

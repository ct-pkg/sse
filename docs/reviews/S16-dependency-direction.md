# S16：依赖方向与 ct-http 审计

> 日期：2026-11-15。CT v0.53.0。ct-http **0.1.0**（annotated tag `v0.1.0` → commit `b4b7b43`）。
> 依据：负责人第 16 题裁定（`ct-http` 更底层，`ct-sse` 依赖 `ct-http`，单向；提案写的
> `ct-http → ct-sse` 是反的）。

## 1 结论

**依赖方向：`ct-llm-sse → ct-sse → ct-http`（箭头读作「依赖」）。**

| 关系 | 结论 | 说明 |
| --- | --- | --- |
| `ct-sse` → `ct-http` | **允许且是产品方向** | SSE 消费 HTTP 交来的字节；集成门禁的 `vendor/http` 就是这个方向 |
| `ct-http` → `ct-sse` | **禁止** | ct-http 不得 import/引用 ct-sse，也不得掺入 SSE 语义 |
| `ct-sse` → `ct-llm-sse` | **禁止** | 那是下游，反向依赖不许 |
| `ct-llm-sse` → `ct-sse` | 允许（不在本仓库） | LLM 语义消费 SSE 事件 |

两条容易混淆的事实，分开写：

1. **架构方向**：`ct-http` 最底层，`ct-sse` 在它上面，`ct-llm-sse` 再上面。集成夹具让
   ct-http 产出真实 chunk 喂给 `feed`，正是这个方向。
2. **编译单元现状**：`sse/sse.h.ct` 不写 `import http::http`，只接受 `char * + len`。
   这是「解析器不绑死传输实现」的解耦，不代表方向反过来；`ct-sse` 的产品依赖仍然在
   `ct-http` 之上。包清单 `ct.pkg` 只有 `requires = ct >= 0.53.0`，没有声明任何包依赖。

提案里 `ct-http → ct-sse` 的写法是反的，已在需求定稿与路线图中改正；**提案原文按留档规则
不改**，纠正在 [研判评估](evaluation.md) 中登记。

## 2 ct-http 0.1.0 实测

### 2.1 取包与布局

```console
$ git clone --depth 1 --branch v0.1.0 https://github.com/ct-pkg/http cfg
warning: refs/tags/v0.1.0 610d9f9... is not a commit!
Note: switching to 'b4b7b4317f3b794b9e54a1544f7e31b8d314c242'.
$ git rev-parse HEAD
b4b7b4317f3b794b9e54a1544f7e31b8d314c242
```

发布线布局（包根即 include 根）：

```text
http/ct.pkg
http/http/http.m.ct
http/http/Types.h.ct
http/http/http.shim.c
http/http/http.shim.h
```

**取包方式说明**：首次 `ct get https://github.com/ct-pkg/http@0.1.0` 失败，原文为
`ctc: git fetch of 'https://github.com/ct-pkg/http' failed`；同一时刻 `git ls-remote` 正常，
`git clone --branch v0.1.0` 成功。审计因此改用**发布 tag 对应的 commit `b4b7b43`**，
不是本地未提交改动。随后复跑 `bash test/integration.sh` 时 `ct get` 成功、门禁绿，
说明首次失败是取包链路的瞬时问题；两段都如实记录，不把失败改写成成功。

### 2.2 逐文件审计：有没有 SSE 语义

| 文件 | 内容 | 是否含 SSE 解析/分发/`text/event-stream` 判断 |
| --- | --- | --- |
| `http/http.m.ct` | 公开映射单元：`pub type CRequest/CResponse`、`HttpEntry`（`char * -> post()`）、`RequestBuilder`（`send_stream(HttpChunkCb, void *)` 等）、`ResponseView` | **无**。只有 HTTP 请求配置、发送、响应只读视图 |
| `http/Types.h.ct` | 一个 `pub enum HttpDefaults { HttpTimeoutDefaultMs = 0 }` | **无** |
| `http/http.shim.c` | libcurl 调用、easy handle、写回调、逐跳跟随、错误归一 | **无**。写回调只把字节交给调用方，不按行/按事件切分 |
| `http/http.shim.h` | C 边界：`HttpRequest`/`HttpResponse`、`HttpChunkCb`、本地错误码 | **无** |
| `http/README.md` | 单元布局说明 | **无** |
| `docs/streaming.md` | 流式交付、所有权、中止、上限 | **无**。明确 chunk 是借用字节，未提事件流 |

### 2.3 原始 grep

```console
$ grep -rni -E "event-stream|server-sent|text/event|last-event|data:|event:|retry:|dispatch" http/
http/http.shim.c:294:/* Sticky by design: a cancelled request is not reusable, rebuild it to retry. */
http/http.shim.c:1120:/* Dispatch through the struct field: no vtable lookup, one indirect call. */
```

两处命中都是**无关注释**：一处说取消后的请求要靠重建来重试，一处说函数指针字段的分派；
没有一处涉及 SSE 字段、行切分、事件边界或 `text/event-stream`。

```console
$ grep -rni -E "content-type|accept|text/" http/
http/http.shim.h:211:/* Test hook: the index-th accepted header as "Name: value", NULL past the end. */
```

没有按 `Content-Type` 分流，也没有 `Accept` 设置或 `text/event-stream` 判断。

```console
$ grep -rn "HttpChunkCb" http/
http/http.shim.h:21:typedef int (*HttpChunkCb)(char *data, int len, void *ud);
http/http.shim.c:486:    HttpChunkCb cb;      /* stream only */
http/http.m.ct:32:    CResponse *send_stream(HttpChunkCb cb, void *ud);
```

`grep -rn "import" http/` 无命中，`grep -rni "sse" http/` 无命中。

### 2.4 接口契约（ct-http 0.1.0）

- `typedef int (*HttpChunkCb)(char *data, int len, void *ud);`
- `CResponse *send_stream(HttpChunkCb cb, void *ud);`
- `data` 是**借用**，只在本次回调内有效；跨回调保留必须自行拷贝（见 `docs/streaming.md` §8）。
- 回调返回非 0 = 中止传输，对外 `error()==23`，`is_cancelled()==0`。
- 流式响应不持有 body：`body()==NULL`、`body_len()==0`、`take_body()==NULL`。

与 `sse_parser.feed(char *, int)` 的所有权约定**不冲突**：`feed` 在返回前把字节拷进 parser
自己的缓冲，从不保留 `chunk` 指针。I-1 夹具已按此跑通（[S13](S13-http-integration.md)）。

## 3 对 ct-http 的建议（只报告，未改一行）

1. **`HttpChunkCb` 的 `data` 建议加 `const`**：当前是 `char *`，而库明确说回调不得修改、
   不得 `free`。`const char *` 能把「借用只读」写进类型；代价是消费方 `feed` 也要接受
   `const char *`（或做一次显式转换）。属于接口演进，不在本包范围内改。
2. **`text/event-stream` 的判断应由消费方做**：ct-http 现在是正确的——它不判断内容类型。
   但 0.1.0 没有暴露响应头回调（`docs/reviews/spec-review/*` 里提过 `HttpHeadersCb`），
   消费方拿不到 `Content-Type` 与状态码的先手判断。建议未来提供只读响应头视图。
3. **`char * -> post()` 的命名与线上方法**：`post()` 只是请求工厂；未设置 body 时
   `http.shim.c` 置 `CURLOPT_HTTPGET=1`，实际发出的是 **GET**。文档与命名容易让人以为
   只能 POST。建议在 `streaming.md` 与 README 写明「工厂名 `post`，无 body 时为 GET」。
   本仓库已在 [S13](S13-http-integration.md) 修正自己的表述，未改 ct-http。
4. **分片边界不保证与写入对齐**：集成夹具靠服务器侧 40ms 间隔让切点落在行内，不是硬保证。
   若未来需要确定性分片，可在测试 seam 上做「按脚本切块」，而不是改解析包。

**ct-http 内部没有任何 SSE 语义需要下沉到 `ct-sse`**，因此没有「下沉跟进」的代码项；
只保留第 2、3 条文档/接口建议。若 ct-http 未来加入 SSE 判断，按
[roadmap](../planning/roadmap.md) 的 PH-14 条件项处理。

## 4 `vendor/` 的方向与发布边界

- 集成门禁在 `mktemp -d` 里取 ct-http 放到 `vendor/http`，include 根是包根
  `-I vendor/http`（绕法，见 S13 §3）。
- 这个方向是**产品依赖方向**（`ct-sse` 站在 `ct-http` 之上），不是「测试反向依赖」。
  测试替身不会改变包的依赖方向，也不会让 ct-http 反过来依赖 ct-sse。
- `vendor/` 目录**不进仓库、不进发布产物**：门禁用完即删。`ct-sse` 的发布产物只有
  `sse/` 与 `ct.pkg`；`test/` 不进包。

## 5 集成门禁的当前状态

`bash test/integration.sh` 的前置检查（ct/git/python3/cc/libcurl）都通过。
首次运行在 `ct get` 的 git fetch 阶段失败（退出码 1，打印原始日志；退出 2 只用于缺少
外部前置条件，不会把它误报成 BLOCKED）。复跑同一命令通过：

```console
$ bash test/integration.sh
ok i1_http_stream (ct-http 0.1.0, real loopback chunks)
```

结论：首次失败是取包链路的瞬时问题，与依赖方向无关；保留记录，不写成「从未失败」。

## 6 作废项

- 「集成测试造成 ct-sse 反向依赖 ct-http」的顾虑**作废**。集成消费 ct-http 是正向产品
  依赖（`ct-sse → ct-http`）；反向边（`ct-http → ct-sse`）从未存在，也不允许存在。
- 此前文档中若有把方向写成 `ct-http → ct-sse` 的表述，以本文与
  [需求定稿](../requirements.md) §2、[roadmap](../planning/roadmap.md) 为准。

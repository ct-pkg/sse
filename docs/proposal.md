# ct-sse 提案（修订版，完全 OO）

> 以下为提案原文，正文未删改。

再增加一个包，同样的级别的。ct-sse 包设计规范（修订版，完全 OO）

依据：Trae 研判（ct-capability-request-review.md）、bindings-and-patterns.md、phase40-draft.md。本修订整合了三条硬约束——L5（own 只认 malloc/calloc，工厂返回裸指针）、L4（回调所有权是契约不是编译器检查）、L9（Vec<char> 的 get 返回值拷贝，不适合零拷贝事件暴露）。

---

1. 设计目标

目标 说明
完全 OOP 所有操作通过对象方法完成
零拷贝事件暴露 SseEvent 字段 borrow 自解析器内部 char* 缓冲区，回调期间有效
跨 chunk 行缓冲 TCP 分片把一行切成两半时，parser 内部无缝拼接
协议正确 严格遵循 WHATWG SSE：event/data/id/retry 四字段，多行 data 用 \n 连接，空行分发，:  开头是注释
错误可恢复 协议错误不崩溃，parser 记录错误状态
薄 不做 HTTP 传输、不做 LLM 协议解析、不做重连

包不做：HTTP（ct-http 负责）、LLM 协议语义（ct-llm-sse 负责）、重连（内核策略）、事件路由（事件总线负责）。

---

2. 关键设计决策（基于 Trae 研判的修正）

决策 理由 依据
缓冲区用 char* + 手动容量管理，不用 Vec<char> SseEvent->data 需要指向连续内存以支持零拷贝 borrow；Vec<char> 的 get 返回值拷贝，O(n) 循环提取会毁掉流式性能 L9 / bindings-and-patterns.md §5
SseParser::new() 返回裸指针，调用方显式 delete own 只认 malloc/calloc 初始化式，工厂方法返回值不能写 own L5 / Memory.h.ct:92
SseEvent 无 Drop，字段 borrow 自 parser 事件是 parser 内部状态的视图，不是独立拥有的对象；跨回调保留必须显式 copy L4 契约第 1、2、5 条
SseEventCb 用 pub typedef 跨模块函数指针类型导出，bindings-and-patterns.md §3 已验证可行 L11
错误用 int 返回码 + error_msg() defer 在 P38 尚未收口，errdefer 明确后置；MVP 用 int 返回 + 提前返回 L8 / phase38-draft.md:28
行上限默认 64KB，可配置 防 OOM；超过上限返回 -1，不无限增长 安全默认

---

3. 类型定义

```ct
// ── 事件快照（字段 borrow 自 parser，回调期间有效） ──
pub struct SseEvent {
    char *event;        // "event:" 字段；缺省或空时为 "message"
    char *data;         // "data:" 字段拼接结果；多行用 '\n' 连接
    int   data_len;     // data 实际长度（data 可含 '\0'，不依赖 strlen）
    char *id;           // "id:" 字段的持久值；未设置或已清除时为 NULL
    int   retry;        // "retry:" 字段（毫秒）；0 表示未设置
};

impl SseEvent {
    int  has_id();      // id != NULL
    int  has_retry();   // retry != 0
    int  is_message();  // event == "message"（含缺省情况）
}

// ── 事件回调（返回 0 继续，非 0 由 parser 决定是否中断） ──
pub typedef int (*SseEventCb)(SseEvent *ev, void *ud);
```

SseEvent 的字段所有权（契约，写进 README）：

1. 回调参数 ev 及 ev->event/data/id 的生命周期到回调返回为止。
2. 要跨回调保留，必须显式 strdup / copy 到调用方管理的内存。
3. 回调不得 delete / free 任何字段——它们 borrow 自 parser。
4. ud 归注册方所有，回调只借不还。
5. parser 被 delete 后，任何从旧 SseEvent 复制的裸指针都可能悬垂。

---

4. SseParser 完整定义

```ct
pub struct SseParser {
    // 行缓冲（跨 chunk 累积不完整的行）
    char *_line_buf;
    int   _line_len;
    int   _line_cap;

    // 当前事件的 data 缓冲（跨行累积）
    char *_data_buf;
    int   _data_len;
    int   _data_cap;

    // 当前事件的 event 类型
    char *_event_buf;
    int   _event_len;
    int   _event_cap;

    // 当前事件的 retry（毫秒）
    int   _retry;

    // 持久 lastEventId（跨事件保留）
    char *_last_event_id;
    int   _last_event_id_len;
    int   _last_event_id_cap;
    int   _last_event_id_valid;

    // 错误状态
    int   _error;
    char *_error_msg;

    // 行分隔符状态（\r\n 与单独 \r 的处理）
    int   _saw_cr;

    // 行长度上限
    int   _max_line_bytes;

    // 回调注册
    SseEventCb _on_event;
    void      *_on_event_ud;

    // 当前事件的视图（借自上述缓冲区）
    SseEvent _current;

} use Drop;

impl SseParser {
    // ── 构造 ──
    static SseParser *new();

    // ── 配置 ──
    SseParser *on_event(SseEventCb cb, void *ud);
    SseParser *max_line_bytes(int bytes);   // 默认 65536

    // ── 核心：增量 feed ──
    // 返回本次 feed 触发的事件回调次数；致命错误返回 -1
    int feed(char *chunk, int len);

    // ── 流结束 ──
    // 处理残留的不完整行，若 data 缓冲非空则分发最后一个事件
    // 返回触发的事件回调次数；错误返回 -1
    int finish();

    // ── 错误查询 ──
    int   has_error();
    char *error_msg();

    // ── 状态查询 ──
    char *last_event_id();     // 最近持久 id；无则 NULL
    int   retry_hint();        // 最近 retry；无则 0

    // ── 复用 ──
    // 重置所有瞬时状态（清空行缓冲、data、event 缓冲、error）；
    // 保留 _last_event_id（用于 Last-Event-ID 重连）与回调注册
    void reset();

    // ── 私有方法 ──
    static int _ensure(char **buf, int *cap, int need);
    static int _push_char(char **buf, int *len, int *cap, char c);
    static int _push_str(char **buf, int *len, int *cap, char *s, int slen);
    int  _process_line();
    int  _handle_field(char *field, int field_len, char *value, int value_len);
    int  _dispatch_event();
    int  _set_error(char *fmt, ...);
}

impl Drop for SseParser {
    // 释放所有内部 char* 缓冲区
    void drop();
}
```

---

5. 内部实现要点

5.1 new() 的语义（L5 约束）

```ct
static SseParser *SseParser::new()
{
    SseParser *p = calloc(1, sizeof(SseParser));
    if (p == 0) return 0;
    p->_max_line_bytes = 65536;
    return p;
}
```

调用方不能写 own SseParser *p = SseParser::new()——own 只认 malloc/calloc 初始化式，工厂返回值不合规。必须：

```ct
SseParser *p = SseParser::new();
// ... 使用 ...
delete p;
```

如果 CT 未来允许工厂方法标记 own，可升级为：

```ct
own SseParser *p = SseParser::new();   // 前提：语言支持
```

在那之前，README 必须明确 new() 返回裸指针，调用方负责 delete。

5.2 Drop 的职责

```ct
void SseParser::drop()
{
    free(self->_line_buf);
    free(self->_data_buf);
    free(self->_event_buf);
    free(self->_last_event_id);
    free(self->_error_msg);
}
```

_current 是 SseEvent 字段，其内部指针指向上面这些缓冲区，不单独释放。

5.3 feed 的行切分与跨 chunk 缓冲

```ct
int SseParser::feed(char *chunk, int len)
{
    int events_fired = 0;
    int i = 0;

    while (i < len) {
        char c = chunk[i];

        // \r\n 与单独 \r 作为行分隔符
        if (c == '\r') {
            self->_saw_cr = 1;
            int r = self->_process_line();
            if (r < 0) return -1;
            events_fired += r;
            i++;
            continue;
        }
        if (c == '\n') {
            if (self->_saw_cr) {
                // \r\n 中的 \n，\r 已处理过
                self->_saw_cr = 0;
                i++;
                continue;
            }
            int r = self->_process_line();
            if (r < 0) return -1;
            events_fired += r;
            i++;
            continue;
        }

        // 普通字符：追加到行缓冲
        self->_saw_cr = 0;
        if (self->_line_len + 1 >= self->_max_line_bytes) {
            return self->_set_error("SSE line exceeds %d bytes",
                                    self->_max_line_bytes);
        }
        if (_push_char(&self->_line_buf, &self->_line_len,
                       &self->_line_cap, c) < 0) {
            return self->_set_error("OOM");
        }
        i++;
    }

    return events_fired;
}
```

关键点：_saw_cr 是 parser 状态，跨 chunk 保留。如果 chunk 在 \r 处断开，下一个 chunk 的 \n 仍被正确识别为 \r\n 的一部分。

5.4 _process_line 的字段分派

```ct
int SseParser::_process_line()
{
    // 空行 → 分发事件
    if (self->_line_len == 0) {
        return self->_dispatch_event();
    }

    // 注释行：以 ':' 开头
    if (self->_line_buf[0] == ':') {
        self->_line_len = 0;
        return 0;
    }

    // 找第一个 ':'
    int colon = -1;
    for (int i = 0; i < self->_line_len; i++) {
        if (self->_line_buf[i] == ':') { colon = i; break; }
    }

    // 无冒号：整行是字段名，值为空
    char *field, *value;
    int field_len, value_len;
    if (colon < 0) {
        field = self->_line_buf;
        field_len = self->_line_len;
        value = self->_line_buf + self->_line_len;   // 空串
        value_len = 0;
    } else {
        field = self->_line_buf;
        field_len = colon;
        value = self->_line_buf + colon + 1;
        value_len = self->_line_len - colon - 1;
        // 规范：值前若有一个空格则去掉
        if (value_len > 0 && value[0] == ' ') {
            value++;
            value_len--;
        }
    }

    int r = self->_handle_field(field, field_len, value, value_len);
    self->_line_len = 0;
    return r;
}
```

5.5 _handle_field 的分派

```ct
int SseParser::_handle_field(char *field, int field_len,
                              char *value, int value_len)
{
    // data: 追加 value + '\n' 到数据缓冲
    if (field_len == 4 && strncmp(field, "data", 4) == 0) {
        if (_push_str(&self->_data_buf, &self->_data_len, &self->_data_cap,
                      value, value_len) < 0)
            return self->_set_error("OOM");
        if (_push_char(&self->_data_buf, &self->_data_len, &self->_data_cap,
                       '\n') < 0)
            return self->_set_error("OOM");
        return 0;
    }

    // event: 设置事件类型；空值清空（回落到 "message"）
    if (field_len == 5 && strncmp(field, "event", 5) == 0) {
        self->_event_len = 0;
        if (value_len > 0 &&
            _push_str(&self->_event_buf, &self->_event_len, &self->_event_cap,
                      value, value_len) < 0)
            return self->_set_error("OOM");
        return 0;
    }

    // id: 更新持久 lastEventId；空值清除
    if (field_len == 2 && strncmp(field, "id", 2) == 0) {
        self->_last_event_id_len = 0;
        if (value_len > 0) {
            if (_push_str(&self->_last_event_id,
                          &self->_last_event_id_len,
                          &self->_last_event_id_cap,
                          value, value_len) < 0)
                return self->_set_error("OOM");
            self->_last_event_id_valid = 1;
        } else {
            // 空值：清除持久 id（规范：id: 清除 lastEventId）
            self->_last_event_id_valid = 0;
        }
        return 0;
    }

    // retry: 纯数字才更新
    if (field_len == 5 && strncmp(field, "retry", 5) == 0) {
        if (value_len > 0 && value_len < 20) {
            char tmp[20];
            memcpy(tmp, value, value_len);
            tmp[value_len] = 0;
            char *end = 0;
            long v = strtol(tmp, &end, 10);
            if (end == tmp + value_len && v >= 0 && v <= INT_MAX) {
                self->_retry = (int)v;
            }
        }
        return 0;
    }

    // 未知字段：忽略（规范要求）
    return 0;
}
```

5.6 _dispatch_event

```ct
int SseParser::_dispatch_event()
{
    // data 缓冲为空：不清空 event/id/retry，直接返回
    // 规范：如果数据缓冲区为空，不触发事件
    if (self->_data_len == 0) {
        // 但仍需清空 event 缓冲（规范：事件类型缓冲区在分发时清空）
        self->_event_len = 0;
        return 0;
    }

    // 去掉 data 末尾的 '\n'
    if (self->_data_len > 0 && self->_data_buf[self->_data_len - 1] == '\n') {
        self->_data_len--;
    }

    // 构造视图
    self->_current.event = (self->_event_len > 0)
                            ? self->_event_buf
                            : "message";
    self->_current.data = self->_data_buf;
    self->_current.data_len = self->_data_len;
    self->_current.id = self->_last_event_id_valid
                         ? self->_last_event_id
                         : 0;
    self->_current.retry = self->_retry;

    // 回调
    int r = 0;
    if (self->_on_event != 0) {
        r = self->_on_event(&self->_current, self->_on_event_ud);
    }

    // 清空事件瞬时状态；retry 也清空（规范：retry 只在当前事件有效）
    self->_data_len = 0;
    self->_event_len = 0;
    self->_retry = 0;

    // 回调返回非 0 时返回错误，但状态已清空
    return (r != 0) ? self->_set_error("callback aborted") : 1;
}
```

5.7 finish 的语义

```ct
int SseParser::finish()
{
    int fired = 0;

    // 处理残留的不完整行（流末尾没有行终止符）
    if (self->_line_len > 0) {
        int r = self->_process_line();
        if (r < 0) return -1;
        fired += r;
    }

    // 规范：流结束时若 data 缓冲非空，分发最后一个事件
    if (self->_data_len > 0) {
        int r = self->_dispatch_event();
        if (r < 0) return -1;
        fired += r;
    }

    return fired;
}
```

5.8 reset 的语义

```ct
void SseParser::reset()
{
    self->_line_len = 0;
    self->_data_len = 0;
    self->_event_len = 0;
    self->_retry = 0;
    self->_saw_cr = 0;
    self->_error = 0;
    if (self->_error_msg != 0) {
        free(self->_error_msg);
        self->_error_msg = 0;
    }
    // 保留 _last_event_id（用于 Last-Event-ID 重连）
    // 保留 _on_event / _on_event_ud
}
```

---

6. 与 ct-http 的集成

```ct
// 内核侧的 SSE chunk 回调
int on_http_chunk(char *data, int len, void *ud)
{
    SseParser *parser = (SseParser *)ud;
    int n = parser->feed(data, len);
    if (n < 0) {
        return 1;   // 通知 ct-http 中断传输
    }
    return 0;
}

// 事件回调
int on_sse_event(SseEvent *ev, void *ud)
{
    LlmStream *stream = (LlmStream *)ud;
    // ev->data 是 borrow，必须 copy 到 stream 内部才能跨回调
    llm_stream_handle_event(stream, ev->event, ev->data, ev->data_len);
    return 0;
}
```

---

7. 错误处理

场景 has_error() error_msg()
行超出上限 1 "SSE line exceeds 65536 bytes"
OOM 1 "OOM"
回调中断 1 "callback aborted"
正常 0 NULL

协议层的非致命情况（未知字段、非法 retry 值、注释行）不报错——规范要求忽略。只有资源耗尽和回调中断才是致命错误。

---

8. 使用示例

8.1 基本流程

```ct
SseParser *parser = SseParser::new();
parser->on_event(on_sse_event, stream);
parser->max_line_bytes(65536);

// 由 ct-http 的 chunk 回调驱动
// ... feed() 被反复调用 ...

// 流结束
parser->finish();

delete parser;
```

8.2 复用 parser 处理新流

```ct
parser->reset();
// parser 保留 last_event_id，可用于 Last-Event-ID 重连
// ... 新一轮 feed() ...
```

8.3 读取持久状态

```ct
char *last_id = parser->last_event_id();
int hint = parser->retry_hint();
if (hint > 0) {
    // 按 retry 建议的毫秒数重连
}
```

---

9. 对 CT 语言的需求映射（基于 Trae 研判）

需求 在 ct-sse 中的用途 状态
L4（回调所有权契约） SseEvent 字段 borrow 契约文档（非语言特性）
L5（own 只认 malloc） SseParser::new() 返回裸指针 包层适配（显式 delete）
L11（函数指针） SseEventCb 通过 pub typedef 已支持
L9（Vec<char>） 不使用——缓冲区用 char* 手动管理 本包不需要
L8（错误传播） int 返回 + 提前返回 defer 等 P38，MVP 用返回码
L2（异构值） 不需要 —
L1（自定义下标） 不需要 —

结论：ct-sse 不阻塞任何 CT 语言特性。它只依赖已经支持的 L11（函数指针）和契约文档（L4）。own 的限制通过显式 delete 绕过。

---

10. 实施顺序

阶段 内容 依赖 产出
S1 SseEvent + SseParser 骨架 + new / on_event / Drop L5 能构造和释放
S2 行缓冲 + _process_line 字段解析 — 能解析单行
S3 _dispatch_event + 回调触发 L4, L11 核心闭环：能吐出事件
S4 跨 chunk 行缓冲 + \r\n 处理 — 分片到达正确
S5 id / retry 持久 + finish — 完整协议
S6 错误处理 + 行上限 — 生产可用
S7 reset + 状态查询 — 可复用

S1–S3 是核心闭环。验收标准：用 WHATWG 规范示例 "data: YHOO\ndata: +2\ndata: 10\n\n"，feed 应触发一次回调，ev->data 为 "YHOO\n+2\n10"（末尾 \n 已去掉）。

---

11. 与上一版的差异

项目 上一版 本版
缓冲区 _line_buf 等手写容量，与 Vec<char> 混用 全部 char* + 手动管理，不用 Vec<char>
new() own SseParser *p = SseParser::new() SseParser *p = SseParser::new() + 显式 delete
SseEvent 有 use Drop 无 Drop——纯视图，borrow 自 parser
错误处理 依赖 L8 int 返回 + 提前返回，不依赖 defer/errdefer
回调契约 假设语言检查 契约文档五条，写进 README
_current 栈上临时 parser 字段，字段 borrow 内部缓冲区
\r\n 处理 简单跳过 \r _saw_cr 跨 chunk 状态，正确处理 \r\n 分片

---

12. 一句话总结

ct-sse 是两个类：SseEvent 是 borrow 视图，SseParser 是增量状态机。所有缓冲区用 char* + 手动容量管理（不用 Vec<char>，因为需要零拷贝事件暴露），new() 返回裸指针、调用方显式 delete（L5 约束），回调所有权是五条契约而非编译器检查（L4）。不阻塞任何 CT 语言特性——L11 已支持，其余靠契约和包层适配。S1–S3 完成后即可跑通“SSE 字节流 → SseEvent 回调”的最小闭环。

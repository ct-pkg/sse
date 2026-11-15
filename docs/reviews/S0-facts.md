# S0 事实核对报告（ct v0.53.0）

> 范围：只读事实核对。提案按 v0.52.0 书写；本机 `~/.local/bin/ct` 实测为 **v0.53.0**，故逐条在 v0.53.0 上重测。
> 探针目录：`/tmp/ct-sse-probe/`（临时目录，不入库）；下文每条给出探针源码要点、命令、退出码与原始输出。
> 判定只认探针输出，不引用提案或历史文档的口径。

## 0 环境

```console
$ ~/.local/bin/ct --version
ct v0.53.0
```

## 1 静态工厂方法（无 namespace / 带 namespace）

### 1.1 `.ct` 单文件里写 `pub` 方法

探针 `p1_static_factory.ct`：

```ct
pub struct Parser { int x; }
impl Parser {
    pub static Parser *new() { ... }
    pub int get() { return self->x; }
}
```

```console
$ ct build p1_static_factory.ct ...
p1_static_factory.ct:9:1: error: a pub method needs a pub struct in a .h.ct unit
ctc: 1 error(s) generated
rc=1
```

结论：`pub` 方法只允许出现在 `.h.ct` 单元的 `pub struct` 固有 `impl` 中（L42-1）。

### 1.2 无 namespace、`.ct` 私有静态方法

`p1d_private_static.ct`（无 `pub`，调用 `Parser.new()`）：

```console
$ ct build p1d_private_static.ct ...
p1d_private_static.ct:10: warning: potential leak: 'p' (Parser*) may leak on a return path (line 11)
cc ... 
rc=0
$ ./p1d_private_static
5 42
```

结论：非泛型静态固有方法的调用面是 `Parser.new()`，可用。

### 1.3 冒号写法 `Parser::new()`

`p1e_private_colons.ct`：

```console
$ ct build p1e_private_colons.ct ...
p1e_private_colons.ct:18:28: error: no function of that name in that namespace
rc=1
```

结论：非泛型 struct 的静态方法**不能**写 `Type::name()`；`::` 留给泛型实例（如 `Vec<int>::from`）。

### 1.4 根命名空间 `.h.ct` + 跨单元

`rootpkg/parser.h.ct`（无 `namespace`，`pub struct` + `pub static Parser *new()`），消费方 `Parser.new()`：

```console
$ ct build rootpkg/main.ct -I rootpkg ...
rootpkg/parser.h.ct:9: warning: potential leak: 'p' (Parser*) may leak on a return path (line 10)
rc=0
$ ./rootmain
7
```

结论：根命名空间单元里静态工厂可用并跨单元调用。

### 1.5 带 namespace 的单元（提案的实际形态）

`nsroot/sse/visibility.h.ct` 声明 `namespace sse;`、`pub static Parser *make()`。三种调用全部失败：

| 调用形态 | 原始输出 | rc |
| --- | --- | --- |
| 单元内部 `Parser.make()` | `visibility.h.ct:26:18: error: use of an undeclared variable` | 1 |
| 消费方 `Parser.make()` | `make1_main.ct:6:23: error: use of an undeclared variable` | 1 |
| 消费方 `sse::Parser.make()` | `no variable of that name in that namespace (qualified type names are not supported; use the bare name or an alias import)` | 1 |

结论：v0.53.0 上**带 namespace 的单元完全不能用静态固有方法**。这是语言缺陷，不是用法问题。
绕法（已实测）：`pub SseParser *sse_parser_new(void)` 自由函数。

```console
$ ct build nsroot/app/main.ct -I nsroot ...
rc=0
$ ./nsmain
5 42
```

## 2 函数指针 typedef 作回调参数

`p3_fnptr.ct`（`typedef int (*EventCb)(int, void *);` 作为 struct 字段与参数）：

```console
$ ct build p3_fnptr.ct ...
rc=0
$ ./p3_fnptr
9
```

跨单元形态 `nsroot/sse/visibility.h.ct` 的 `pub typedef int (*EventCb)(int, void *);` 生成：

```c
typedef int (*sse_EventCb)(int, void *);
```

消费方输出 `9 abc 5`，rc=0。结论：成立。

## 3 `errdefer` 在方法体内的行为

| 探针 | 结果 | 原始输出 |
| --- | --- | --- |
| `p6c`：方法体内 `errdefer { ... }` + `return err: 1;` | 触发 | `cleanup` / `0 1`，rc=0 |
| `p4`：方法体内 `errdefer` + 普通 `return -1;` | **不触发** | `0 -1 3`，无 `cleanup`，rc=0 |
| `.h.ct` 单元内 `errdefer` | 硬错 | `errdefer.h.ct:7:5: error: errdefer is not allowed here`，rc=1 |

结论：`errdefer` 只在 `return err:`/`break err:`/`continue err:` 错误出口执行，普通负数返回不触发；且 `.h.ct` 禁止使用。
本包实现必须在 `.h.ct` 里，故 `errdefer` **不可用**；提案改用 `int` 返回 + `error_msg()` 的分支正确。

## 4 方法级 `pub` 与私有方法混用

`nsroot/sse/visibility.h.ct`：`pub get/fire/current/on_event`，私有 `secret`。

- 生成头只导出 pub 方法；私有方法在 `.c` 里发射 `static __attribute__((unused))`。
- 消费方调用私有方法：

```console
$ ct build nsroot/app/priv_main.ct ...
priv_main.ct:7:23: error: method is private to its unit
rc=1
```

结论：v0.53.0 已有方法级可见性（Phase 42），提案「`_xxx` 会全部进生成头、没有方法私有」的口径**过时**。

## 5 `impl Drop` 必须带函数体

```ct
impl Drop for Parser {
}
```

```console
$ ct build droppkg/main.ct ...
Undefined symbols for architecture arm64:
  "_Parser_Drop_drop", referenced from:
      _main in main-6a6481.o
ld: symbol(s) not found for architecture arm64
rc=1
```

补上 `void drop() { }` 后：

```console
$ ./dropmain
0
deleted
rc=0
```

结论：空 `impl Drop` 能过前端但链不上，`drop()` 必须有函数体；成立（并且必须在 S1 就写体）。

## 6 链式方法返回自身指针

```ct
Parser *q = p->on_event(sink, 0)->max_line_bytes(64);
```

```console
$ ct build p5_chain.ct ...
p5_chain.ct:30:1: error: method receiver must be a variable, an element, a call or a field chain
rc=1
```

拆成中间变量后：

```ct
Parser *q = p->on_event(sink, 0);
q = q->max_line_bytes(64);
```

```console
$ ./p5b
64 64
rc=0
```

结论：方法返回 `self` 可以；**方法结果不能作为下一跳接收者**（SH-73）。API 不得承诺流式链式调用，文档示例必须逐句落变量。

## 7 私有方法互相调用

- 先定义后被调用：`mini.h.ct` 的 `push → append → grow` 正常，输出 `2`，rc=0。
- 后定义先调用：

```console
$ ct build nsroot/app/order_main.ct ...
order.h.ct:9:1: error: no method 'second' for type 'struct sse_Order'
rc=1
```

- 方法名加前导下划线：

```console
$ ct build nsroot/app/mini_main.ct ...   # self->_grow(1)
mini.h.ct:14:1: error: no method '_grow' for type 'struct sse_Mini'
rc=1
```

结论：impl 内方法**没有前向声明**，helper 必须写在调用者之前；私有方法名**不得以 `_` 开头**（字段 `_x` 不受影响）。

## 8 `MAX_CALLS` 1024 的计量口径

| 探针 | 结果 |
| --- | --- |
| 单文件 1024 个直接调用点 | 构建通过 |
| 单文件 1025 个直接调用点 | `calls1025.ct:1031:19: error: too many calls`，rc=1 |
| 600 调用单元 + 500 调用主单元（两个单元） | `main500.ct:431:19: error: too many calls`，rc=1 |
| 600 调用单元 + 400 调用主单元 | 构建通过 |

结论：`MAX_CALLS` 是**单次 `ct build` 内所有单元累计的直接调用边数**，不是每单元 1024。按本包候选 API（约 10 个公开方法、约 15 个私有 helper、每方法 3–8 个调用点）估算，包内调用点约 120–200，占上限 12%–20%。**拆包不解决**（上限按整次构建累计）；只有减少调用点或拆分最终可执行程序的构建才有用。

## 9 `Vec<T>` 是否有借用指针出口

`lib/std/Vec.h.ct` 的公开方法只有 `len/get/has/set/push/pop/clear/release`；`get` 返回值拷贝，没有 `data()`/`ptr()`。提案对 CT 组的可选请求在 v0.53.0 上不存在，本包亦不使用 `Vec`（走 `char *` 手动缓冲）。

## 10 其他已核实项

| 项 | 结果 |
| --- | --- |
| 自由函数变参 + `va_list`/`vsnprintf`（`.h.ct`、带 namespace） | 通过，输出 `SSE line exceeds 65536 bytes`，rc=0 |
| `SseEvent` 按值内嵌进 `SseParser` | 通过（`visibility` 探针输出 `9 abc 5`） |
| 带 namespace 的 `pub struct` + `use Drop` + `delete` | 通过，`Drop` 正常调用 |
| 构造函数 `return calloc(1, sizeof(T));` 单行返回 | 无 CT 泄漏告警；先落局部再初始化再返回会报 `potential leak` 告警 |

## 11 对提案的关键修正（事实层）

1. `SseParser::new()` 写法在 v0.53.0 上不存在：非泛型静态方法用 `Type.name()`，且带 namespace 时静态方法整体不可用。→ 改用自由函数 `sse_parser_new()`。
2. 方法级 `pub` 已落地，helper 默认私有即可；无需自由 `static` 函数绕行（但 helper 名不能 `_` 开头、必须先定义）。
3. `errdefer` 在 `.h.ct` 被禁，且普通返回码不触发；提案不依赖它是正确选择。
4. `finish()` 的「流末分发残留事件」与 WHATWG「EOF 丢弃 pending data」相反，见 battle B-1/B-2。
5. `retry` 用 0 表示未设置与 WHATWG 允许 `retry: 0` 冲突，见 battle B-6。
6. 链式调用不可作为标准路径，见 §6。

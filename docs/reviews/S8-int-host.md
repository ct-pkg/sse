# 内置类型作宿主：实测能力表（ct v0.53.0）

> 触发：负责人指出「int 也可以」。本报告只记录探针事实，不迎合也不反驳。
> 探针目录：`/tmp/ct-sse-probe/`（临时目录，不入库）。

## 1 `impl int` 三种位置

| 位置 | 探针 | 原始输出 | rc |
| --- | --- | --- | --- |
| 带 `namespace` 的 `.h.ct` | `namespace sse; impl int { pub int twice() { return self + self; } }` | `sse/intimpl.h.ct:3:10: error: impl of an unknown trait` | 1 |
| 带 `namespace` 的 `.m.ct` | `namespace sse; impl int { pub int thrice() { return self * 3; } }` | `sse/intm.m.ct:3:1: error: a .m.ct unit cannot contain an impl` | 1 |
| 无 `namespace` 的 `.h.ct` | `impl int { pub int inc() { return self + 1; } }` | `plain.h.ct:1:1: error: impl of an unknown trait` | 1 |
| 普通 `.ct` | 同上，写在 `main` 之前 | `mainimpl.ct:3:10: error: impl of an unknown trait` | 1 |

结论：**`impl int` 在 v0.53.0 不被接受**。`impl` 的属主必须是本单元已声明的 struct 名；`int` 不是。
三处报错原文已固定，不存在「换个单元就能过」的位置。

## 2 `impl` 的其他属主

| 写法 | 原始输出 | rc |
| --- | --- | --- |
| `impl Str`（在未声明 Str 的单元） | `strimp.h.ct:3:10: error: impl of an unknown trait` | 1 |
| `impl char *` | `charp.h.ct:3:11: error: impl of an unknown trait` | 1 |
| `impl int *` | `intp.h.ct:1:1: error: impl of an unknown trait` | 1 |

- `lib/std/Str.h.ct` 里的 `impl Str` 能成立，是因为 `Str` 就在该单元声明；方法体用 `self->data`/`self->len`，说明 `self` 是 `Str *`（地址），不是值。
- 指针类型和内置标量都没有 `impl` 形态。

## 3 int 真正可用的宿主形态：`.m.ct` 静态映射

`intmap/intmap.m.ct`：

```ct
namespace intmap;
#include "intmap.shim.h"

pub trait IntSteps {
    int twice();
}

map trait IntSteps for type int {
    twice(v) -> intmap_twice(v);
}
```

`intmap/intmap.shim.h`：`static inline int intmap_twice(int v) { return v * 2; }`

消费方：

```ct
int x = 4;
int a = x.twice();
int b = (4).twice();
int c = (5).twice();
```

```console
$ ct build intmap/main.ct -I <probe-root> ...
rc=0
$ ./intmapmain
var=8 temp=8 temp5=10
```

要点：

- `int` 可以「挂方法」，但机制是 `map trait … for type int`，**不是** `impl int`。
- 映射只能写在 `.m.ct`；消费方必须 `import` 该映射单元。
- 方法没有 `self`，接收者是显式参数 `v`（按值）。
- 临时值接收者可用：`(4).twice()`、`(5).twice()` 都通过。
- 裸 `5.twice()` 不成立：`intmap/lit.ct:6:15: error: unexpected token`（`5.` 先被词法分析成浮点字面量），要写 `(5).twice()`。
- `.m.ct` 零产物：方法在消费方 `.c` 里展开成 `static inline` shim 调用，不进生成头、不产生链接符号、不影响 ABI。
- 若 shim 函数不是 `static`，才会新增 C 链接符号；命名需自行避让标准库。

## 4 struct 宿主的临时接收者

`ptpkg`：`pub struct Point { int x; int y; }`，`impl Point { pub int sum() }`。

```ct
int a = make_point(1, 2).sum();
int b = (Point){ 3, 4 }.sum();
```

```console
$ ./ptmain
3 7
rc=0
```

- 自由函数返回值、复合字面量都可以作 struct 方法接收者。
- 不能作接收者的是**方法调用结果**：`p->a()->b()` 仍报 `method receiver must be a variable, an element, a call or a field chain`（SH-73）；`call` 指函数调用，不含方法调用。

## 5 能力表

| 形态 | 能写 | 不能写 / 报错原文 |
| --- | --- | --- |
| `impl int`（`.h.ct`，带/不带 namespace） | — | `impl of an unknown trait` |
| `impl int`（`.m.ct`） | — | `a .m.ct unit cannot contain an impl` |
| `impl char *` / `impl int *` | — | `impl of an unknown trait` |
| `impl Str`（非声明单元） | — | `impl of an unknown trait` |
| `impl X`（X 为本单元声明的 struct） | 是；`self` 是 `X *`；pub 方法进生成头 | — |
| `map trait … for type int`（`.m.ct`） | 是；无 `self`，接收者为值参数；临时值 `(4).m()` 可用 | 裸 `5.m()` 不成（词法） |
| `map trait … for type char *`（`.m.ct`） | 是（[examples/48_string_steps] 已跑通） | — |
| struct 临时接收者 | 函数调用结果、复合字面量可用 | 方法调用结果不可作下一跳 |
| int 宿主导出/ABI | `.m.ct` 零产物，无头文件导出、无链接符号 | shim 非 static 时会新增 C 符号 |

## 6 注册表为什么仍用 struct 宿主

负责人指定的形态要求宿主**携带状态**：

```ct
SseRegistry base;
SseRegistry reg = base.reg("parser", sse_parser_new);
SseParser *p = reg.make("parser");
```

- `int` 没有字段，`base.reg(...)` 无处存放 `count`/`names`/`fns`。要让它工作，只能把条目放进 `.m.ct` shim 里的全局表，`int` 退化成索引：
  - 多个 registry 共享同一张全局表，失去值语义；
  - `.m.ct` 不能 import `.h.ct`（`a .m.ct unit can only import another .m.ct unit`），shim 看不到 `SseParser` / `SseCtor`，构造器只能退化成 `void *`；
  - 仍要额外的全局状态与容量上限，和 struct 宿主相比没有更省，反而多一层 C shim。
- struct 宿主用 8 组 `names`/`fns` 固定数组按值传递，`init`/`reg` 返回 `*self`，实测可直接写 `SseRegistry reg = base.reg(...)`、`reg = reg.reg(...)`，无堆分配、无全局表。
- 因此：**int 能挂无状态方法，但不能承载注册表状态；注册表保留 struct 宿主（S8），不改 int。**

## 7 门禁

```console
$ bash test/run.sh s8_registry
ok s8_registry
$ ASAN=1 bash test/run.sh s8_registry
ok s8_registry
$ for t in s1_construct ... s8_registry; do bash test/run.sh $t; done
（10 个夹具全 ok）
```

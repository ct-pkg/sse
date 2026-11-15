# 构造形态探针与裁定

> 背景：v0.53.0 的带 `namespace` 单元不能用静态固有方法（[S0-facts](S0-facts.md) §1.5）。
> 负责人提出两条替代：A 全局实例挂实例方法；B 字符串键 + 函数指针分派表。
> 结论先行：**两条都能编能跑，但都不比自由函数更可用；保留 `sse_parser_new()`，不改实现。**
> 探针目录：`/tmp/ct-sse-probe/nsroot/`（临时目录，不入库）。

## A 全局实例工厂

`sse/factory.h.ct`：

```ct
namespace sse;

pub struct Widget { int v; }
impl Widget { pub int get() { return self->v; } }

pub struct WidgetFactory { int tag; }
impl WidgetFactory {
    pub Widget *make() {
        Widget *w = calloc(1, sizeof(Widget));
        if (w == 0) return 0;
        w->v = 41;
        return w;
    }
    pub Widget *make_raw() { return calloc(1, sizeof(Widget)); }
    pub int tag_value() { return self->tag; }
}

pub WidgetFactory widget_factory;
```

消费方 `sse::widget_factory.make()`（不加重定向指针）即可：

```console
$ ct build nsroot/app/factory_direct.ct ...
factory.h.ct:21: warning: potential leak: 'w' (sse_Widget*) may leak on a return path (line 22)
rc=0
$ ./factory_direct
direct=41 tag=0
```

`&sse::widget_factory` + `f->make()` 同样可用：

```console
$ ./factory_ptr
viacptr=41 tag=0
```

返回裸 `calloc` 的 `make_raw()` 单独看没有告警：

```console
$ ./factory_raw
raw_v=0 tag=0
```

### 边界

| 问题 | 实测 |
| --- | --- |
| 初始化时机 | `tag=0` 说明全局对象在 `main` 前已零初始化，首次调用即有效；不需要注册步骤 |
| 静态初始化依赖 | `Widget *g_early = sse::widget_factory.make();` 编译失败：`error: initializer element is not a compile-time constant`，rc=1 |
| 告警成本 | 工厂若「分配 + 初始化字段」则 CT 报 `potential leak`；本包门禁拒绝任何 `warning:`。返回裸 `calloc` 可避开，但方法就不使用 `self` |
| ABI 面 | 生成头导出 `extern struct sse_WidgetFactory sse_widget_factory;`，全局可写、布局公开 |

## B 字符串键分派表

`sse/registry.h.ct`：

```ct
namespace sse;

pub typedef Widget *(*WidgetMake)(void);
pub struct WidgetEntry { char *name; WidgetMake fn; };

pub WidgetEntry widget_table[4] = {
    { "widget", make_widget },
    { "other", make_widget },
    { "dup", make_widget },
    { "dup", make_other }
};
pub int widget_table_len = 4;
```

消费方自己遍历表（或由库再导出 lookup 自由函数）：

```console
$ ct build nsroot/app/registry_main.ct ...
registry.h.ct:20: warning: potential leak: 'w' (sse_Widget*) may leak on a return path (line 21)
registry.h.ct:28: warning: potential leak: 'w' (sse_Widget*) may leak on a return path (line 29)
rc=0
$ ./registry_main
hit=42 miss_null=1 dup_first=42
```

### 边界

| 问题 | 实测 |
| --- | --- |
| 静态数组还是入口注册 | 常量初始化数组在 load 时即完整，无需注册；增删工厂要改库并重编 |
| 缺失键 | 查不到返回 0；调用方必须判空，运行期才知道 |
| 键冲突 | 两条 `"dup"` 静默取第一条（`dup_first=42`），无冲突检测、无告警 |
| 消费方耦合 | 生成头导出 `extern struct sse_WidgetEntry sse_widget_table[4];` 与 `sse_widget_table_len`；消费方要么自己写遍历（依赖表布局），要么调用库导出的 lookup 自由函数 |
| 告警成本 | 与 A 相同，工厂初始化字段即触发 `potential leak` |

## 对比与裁定

| 维度 | A 全局实例 | B 字符串表 | 自由函数（现状） |
| --- | --- | --- | --- |
| 跨单元可用 | 是 | 是 | 是 |
| 首次调用前有效 | 是（零初始化） | 是（常量数组） | 是 |
| 需要注册步骤 | 否 | 否 | 否 |
| 名称解析 | 编译期方法名 | **运行期字符串** | 编译期符号 |
| 失败模式 | 无（方法存在） | 缺失键→0；冲突→静默取第一条 | 无（链接期报错） |
| 额外公开面 | 可变全局对象 + 布局 | Entry 类型 + 函数指针类型 + 表 + 长度 | 一个函数 |
| 门禁告警 | 工厂初始化即 `potential leak` | 同 A | 无（直接 `return calloc`） |
| 使用负担 | 多一个全局对象概念 | 多一层查表/判空/键唯一性维护 | 直接调用 |

裁定：**保留 `sse_parser_new()`**。

1. A 的全局对象只为承载一个不使用 `self` 的方法，增加可变全局与 ABI 面，换不到任何能力；使用形态 `sse::widget_factory.make()` 与 `sse::sse_parser_new()` 等价，自由函数更直接。
2. B 把编译期符号换成运行期字符串查表，新增「缺键」「重键静默」两种失败模式；要消除它们仍需导出一个 lookup 自由函数——绕一圈回到自由函数，还多出 Entry/函数指针类型/表/长度四个公开符号。
3. 两条在「分配 + 初始化」时都会触发 CT 的 `potential leak` 告警，而本包门禁要求零 `warning:`；自由构造函数以 `return calloc(...)` + 惰性默认值规避，已实测无告警。
4. 两条都没有解决静态初始化调用问题（`initializer element is not a compile-time constant`），因此不存在「初始化时机更好」的收益。

因此不满足「比自由函数更可用」的门槛，按负责人要求保留自由函数，并在 README 注明两条替代形态已被实测否决。

## 后续（S8）：负责人指定「返回宿主自身」的注册表

本报告否定的是「全局单例」和「字符串键全局表」两种形态。S8 采用另一条：
`SseRegistry` **struct 宿主按值返回**，`reg`/`init` 返回宿主自身，`make` 返回
构造对象；实测可写 `SseRegistry reg = base.reg(...)`、`reg = reg.reg(...)`。
`int` 宿主的 `impl int` 不被接受，`map trait` 只能挂无状态方法，无法承载
注册表状态，故不采用。详见 [S8-int-host](S8-int-host.md)。

## 门禁回归（未改实现）

```console
$ for t in s1_construct s2_basic s3_fields s4_chunk s5_limits s5_abort s6_copy s6_finish_eof s7_integration; do bash test/run.sh $t; done
ok s1_construct
ok s2_basic
ok s3_fields
ok s4_chunk
ok s5_limits
ok s5_abort
ok s6_copy
ok s6_finish_eof
ok s7_integration
$ ASAN=1 bash test/run.sh s6_copy
ok s6_copy
$ ASAN=1 bash test/run.sh s6_borrow_uaf
ok s6_borrow_uaf (asan abort as expected)
```

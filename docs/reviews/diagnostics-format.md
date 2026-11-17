# 诊断格式探针与门禁判定（PH-12）

> 日期：2026-11-17。环境：macOS arm64、Apple clang 21.0.0、CT v0.63.0。
> 目的：把 `test/run.sh` 的 `warning:` 文本匹配换成可机械判定的级别信号。
> 结论：**CT 语义诊断走 `--diagnostics=json`；C 编译警告由 `-Werror` 升级为错误，以构建
> 退出码判定。** 门禁不再匹配 `warning:` 文本。

## 1 探针一：CT 语义诊断可用 JSON

```console
$ cat t.ct
int f(int x) { return x; }
int main(void) { return f("s"); }

$ ctc check t.ct --types --diagnostics=json
{"warnings":[{"severity":"error","type":"type_mismatch","file":"t.ct","line":2,"col":25,"callee":"f","message":"argument 1: expected 'int', got 'char *'"}]}

$ ct build t.ct --diagnostics=json
{"warnings":[{"type":"type_mismatch","file":"t.ct","line":2,"col":25,"callee":"f","message":"argument 1: expected 'int', got 'char *'"}]}
'cc' -std=c99 -I '.ctbuild' '.ctbuild/t.c' '-o' 'a.out'
t.ct:7:14: error: incompatible pointer to integer conversion passing 'char[2]' to parameter of type 'int' [-Wint-conversion]
...
```

- `ctc check` 的 JSON 带 `severity`、`type`、`file`、`line`、`col`，可按级别判定。
- `ct build` 的 JSON 对 CT 语义错误也会输出；CT 生成 C 之后，C 编译器的诊断仍是文本。
- 解析错误的 JSON 探针：

```console
$ printf 'int main(void) {\n' > p.ct
$ ctc check p.ct --diagnostics=json
p.ct:1:1: error: unexpected token
```

解析错误仍走文本（退出码 1），因此 JSON 不是所有诊断的统一通道；门禁不能只靠 JSON。

## 2 探针二：C 警告在 `-Werror` 下是错误

```console
$ cat w.ct
int main(void) { int unused = 0; return 0; }

$ ct build w.ct --cflags "-Wall -Wextra -Werror"
'cc' -std=c99 -Wall -Wextra -Werror -I '.ctbuild' '.ctbuild/w.c' '-o' 'a.out'
w.ct:3:9: error: unused variable 'unused' [-Werror,-Wunused-variable]
...
$ echo $?
1
```

`test/run.sh` 的 `cflags` 恒含 `-Wall -Wextra -Werror`；任何 C 警告都会变成错误，`ct build`
退出非 0。原 `grep -q 'warning:'` 在这种构建下不会命中（警告已是 `error:`），属于死代码；
真正拦截警告的是 `-Werror` + 退出码。

## 3 探针三：编译器 JSON 不可用（为什么不用 clang JSON）

```console
$ cc -fdiagnostics-format=json -x c -c /dev/null -o /tmp/null.o
error: invalid value 'json' in '-fdiagnostics-format json'
```

Apple clang 21 不接受 `-fdiagnostics-format=json`（`clang` 同样拒绝）。因此不把门禁绑定到
编译器 JSON；改用第 2 节的级别升级路径。该探针保留，防止以后有人误以为“加个 JSON 参数”就
能替换文本匹配。

## 4 判定规则

| 诊断来源 | 通道 | 门禁判定 |
| --- | --- | --- |
| CT 语义诊断 | `ct build --diagnostics=json`（stdout） | 构建退出码非 0 即失败；JSON 保留给人读/后续消费，不做文本匹配 |
| C 编译警告 | `-Wall -Wextra -Werror` | 警告升级为错误，`ct build` 退出非 0 即失败 |
| CT 解析错误 | 文本 + 退出码 1 | 构建退出码非 0 即失败 |

**E-2 的满足方式**：注入未使用参数 → `-Werror` 把它升级为 error → `test/run.sh` 在
`ct build` 失败处退出 1。原因来自诊断级别（error），不是 `warning:` 文本匹配。

## 5 已知限制

1. CT 若在**不改变退出码**的情况下输出非致命警告，当前门禁不会拦截。CT v0.63.0 的
   `ct build` 走 L0，L0 不产生警告；该限制随 CT 版本变化复核。
2. 解析错误的 JSON 通道未统一（见 §1 最后一段）；门禁只依赖退出码，不依赖该通道。
3. 该判定不覆盖运行时 sanitizer 结论；ASan/LSan 仍按各自门禁（roadmap §6、PH-13）。

## 6 复现

```console
$ ct --version
ct v0.63.0
$ bash test/gates/g12_warning.sh
ok g12_warning (level-based, exit=1)
```

# 值管理架构重构设计

**状态:已实现(S1–S15;dehandle 收口见 `TODO.md` §3.17;本文保留设计决策与迁移前盘点)**
**日期:2026-11**
**关联分支:`main`**

本文档记录 `SwiftJavaScript` core 的值管理架构重构。最终用户面是
public `JS*` 协议 + `JSC*`/`QJS*` 具体类型；public 协议不暴露任何引擎 handle
类型或 handle 级成员，handle 层、落账原语与 driver 协议都在各引擎模块的
package 内部（core 不再有 handle 声明，见 `TODO.md` §3.18）。
下文标注为“迁移前”的分层与 `JSValue<E>` 等泛型名称只表示设计历史，当前 API
见 `Sources/SwiftJavaScript/Surface/`。

本文档结合三方面输入:

1. 当前代码现状(`scope_arena` 分支,含未提交的 `ScopeCore`/`JSScope` 工作);
2. Swift 6.4 所有权能力边界(SE-0503/SE-0499 转正,`@lifetime` 仍为实验特性);
3. V8 绑定设计文档《执行隔离与持久引用设计》中的分层思想(身份 / 访问 / 执行权分离,HandleScope/Local 建模,registry 托管持久句柄)。

---

## 1. 设计目标

1. 用一套统一的值生命周期模型同时覆盖 JSC(GC 管理)与 QuickJS(引用计数)两种引擎语义。
2. 消除回调值逃逸与误用的正确性缺口,优先以类型系统约束,运行时检查兜底。
3. 将作用域栈从线程 TLS 迁至 context 挂载,值操作以 context 寻址;scope 收敛为生命周期边界与合法入口凭证(§3.4)。
4. 为未来 Swift lifetime 依赖特性转正预留演进路径,但不使公共 API 依赖实验特性。
5. 保持 `Sources/SwiftJavaScript` 引擎无关、facade/backend 只做桥接的既有分层原则。

### 1.1 核心原则(承接 V8 设计文档,映射到本仓库)

**V8 文档的三个分离:**

| V8 文档概念 | 本仓库对应物 |
|---|---|
| 本地值 `Local<T>`(有效性与 Scope 绑定,不存 context) | `JSValue` 协议 + `JSCValue`/`QJSValue` 本地视图(§3.2):不持有、不释放;具体类型在 package 内以 borrowed handle + context handle 寻址 |
| 持久引用(持有不授权访问、不保活) | `JSPersistentHandle` 协议 + `JSCPersistentHandle`/`QJSPersistentHandle`:identity 决定绑定(§3.5) |
| 访问见证(必须经合法上下文恢复 Local) | 值操作在引擎具体类型内部经 package handle 寻址 + context 挂载作用域栈(§3.4);恢复入口是 context/scope 的值级 API |
| 执行权限(actor / Locker) | `JSContext` 协议 + `JSCContext`/`QJSContext` actor + `JSVirtualMachine` 专用线程 executor |

**本仓库新增的第四维:释放记账。** V8 的 Local 生命周期由 HandleScope 在引擎内部管理;本仓库的引擎差异要求 core 自己记账——QuickJS 的 `ValueHandle` 引用计数必须配平(`releaseCreatedHandle` = `JS_FreeValue`),JSC 则由 GC 接管(`releaseCreatedHandle` = no-op)。arena 就是这份记账的载体,它不是可优化项,而是 QuickJS 正确性的运行时事实来源。与之并存的是**根域差异**:JSC 未 Protect 的值靠保守扫描执行线程栈存活,QuickJS 靠与位置无关的引用计数——挂起点把引用帧从栈搬进堆,对 JSC 即脱根(§2.4、§3.7)。

**闭包边界是生命周期信息的断层。** `JSFunctionCallback<E>` 是闭包类型;Swift 6.4 的 lifetime 依赖标注无法出现在闭包签名上(实验性的函数类型语法也存在 copy→borrow 转换未实现等缺口)。因此"回调值不逃逸 scope"这一约束在可预见的工具链周期内无法交给编译器,必须由 `~Copyable` 借用签名 + arena 释放纪律 + 显式提升(`persist`)共同承担。

**设计基准是目标能力清单,不是存量使用。** 本库尚在构建期,任何"当前无人引用"对所有目标能力都成立,不构成排除论据;判断标准只能是:能力是否属于目标 API 面、成本是否匹配、时序是否合理。

**本地值不携带所有权,持久引用不保活。** JS 值的日常形态是本地值:有效性严格短于 context,由声明式约束保证(结构化约束先行,`@lifetime` 转正后编译期化),而不是靠保活 context 或运行时检测。长期存储的唯一形态是可恢复 handle——生命周期语义同 ThreadLocal/AsyncLocal:绑定住在容器(Context/Runtime)侧,持有者只持有 identity,容器消亡后解析返回空而非悬垂。

---

## 2. 迁移前状态(历史)

以下分层与问题记录迁移起点;S1–S15 已把用户面切换为协议 + 具体类型,
问题清单中的缺口均已收口。

### 2.1 值类型分层(迁移前 → 当前)

| 迁移前 | 当前 |
|---|---|
| `JSValue<E>` 自持(24 字节 storage words,deinit 释放) | `JSValue` 协议 + `JSCValue`/`QJSValue` 非拥有本地视图,arena 拥有引用 |
| `JSCallbackValue<E>` 可拷贝、经 TLS 解析 context | `JSCallbackValue` 协议 + `JSCCallbackValue`/`QJSCallbackValue`,`~Copyable`;具体类型在 package 内保存 handle + context handle |
| `JSCallbackReturn<E>` 三态 handoff | `JSCallbackReturn` 协议 + `JSCCallbackReturn`/`QJSCallbackReturn` |
| `JSPropertyStringKey<E>` / `JSPreparedScript<E>` | `JSPropertyStringKey`/`JSPreparedScript` 协议 + `JSC*`/`QJS*` 自持有输入 |

### 2.2 作用域层(迁移前)

```
ScopeCore<E>                      ← 共享内核(未提交)
  ├── driverContextHandle
  ├── ScopeArena(created: [Handle], removed: Set<Handle>)
  ├── drain()                     ← 释放所有未 persist/未 handoff 的 handle
  ├── 值工厂(makeString/Number/Boolean/Null/Undefined/Symbol/Object/Array)
  ├── persist(_: JSCallbackValue) → JSValue      ← 显式提升:从 arena 摘除 + retain
  └── `return`(_:) → JSCallbackReturn             ← 临时值 handoff

JSInstantContext<E>: ~Copyable    ← 自动 scope:init push TLS,deinit drain + pop
JSScope<E>: ~Copyable             ← 手动 scope(未提交):open() push,deinit drain + 条件 pop
```

当前实现见各引擎模块的 `HandleLayer/ScopeCore.swift` 与
`HandleLayer/JSScopeWitness.swift`（JSC 在 `Sources/SwiftyJavaScriptCore`,
QuickJS 在 `Sources/SwiftyQuickJS`,Mock 在
`Tests/SwiftJavaScriptTests/HandleLayer`）;`ScopeCore` 只保留 handle 级
package API(值级操作由引擎 scope 直接实现),`JSCInstantContext`/`JSCScope`/
`QJSInstantContext`/`QJSScope` 是具体类型。

### 2.3 执行层

- `JSVirtualMachine` 协议 + `JSCVirtualMachine`/`QJSVirtualMachine`:
  `RuntimeHandle` + 专用线程 `SerialExecutor`——执行线程身份固定,强于普通 actor
  的串行保证,满足 JSC/QuickJS 的线程约束(对应 V8 文档"固定 OS 线程"分支)。
- `JSContext` 协议 + `JSCContext`/`QJSContext` actor:绑定 VM executor;所有
  公共操作经 `withInstantContext` 进入同步 scope。**actor 保证执行互斥,scope
  保证引用生命周期,二者职责不同且都已存在**——这与 V8 文档 §6.3 的结论一致。

### 2.4 引擎语义差异

| 维度 | JSC | QuickJS |
|---|---|---|
| 值保活 | GC + `JSValueProtect`(`retainReference(in:)`) | 引用计数(`JS_DupValue`/`JS_FreeValue`) |
| 未显式根的值的根域 | 保守扫描**执行线程的栈**(引用入堆即不可见;`JSValueProtect` 为堆存储必需——JSValueRef.h 原文:"Use this method when you want to store a JSValue in a global or on the heap") | 引用计数,与引用位置无关 |
| `releaseCreatedHandle` | no-op | `JS_FreeValue` |
| arena 的作用 | 释放记账(GC 场景近似形式化) | **正确性必需**,漏 drain = 泄漏,早 free = use-after-free |
| 堆边界 | runtime(context group)内跨 context 兼容(`isContextCompatibleWith`) | runtime 内多 context |

两引擎的堆都挂在 runtime 层而非 context 层——这决定了持久 handle 层绑定粒度的选择基准:`RuntimeLocal` 有堆边界支撑,`ContextLocal` 有 realm 级差异(全局对象/构造函数)支撑,公开面待定(§3.5、§7)。

**挂起点是根域边界。** `await` 把引用帧从栈搬进堆分配的协程帧——JSC 下未 Protect 的值随之脱根,挂起期间同 actor 的其他执行(含 host 回调)触发分配与 GC 即可回收它,恢复后即悬垂。对照:V8 的 HandleScope 本质是把隐式根域做成显式结构(handle block 挂进 isolate 根链),所以跨挂起点安全;QuickJS 引用计数与位置无关,亦安全。由此得出最小规则:**未显式根化的值不得离开同步栈窗口(跨挂起点、进堆存储);显式根化(`persist`/`JSValueProtect`/持久 handle)是唯一跨窗口手段**——该规则在 JSC 上是引擎硬约束,在 V8 模型/QuickJS 上是"可以但没必要",API 取交集换单一规则(§3.7)。

### 2.5 迁移前问题(已收口)

以下保留迁移起点的问题分级,便于追溯设计决策;当前实现已按 §3 收口。

**P0 – 作用域栈挂在线程上(TLS)**
`JSCallbackValue.resolveContext()` 从 `Thread.threadDictionary` 读 scope 栈。病根需要精确表述:**ambient 栈顶解析本身不是错**——V8 的 `HandleScope` 栈同样是 ambient,挂在 isolate 上;错在把这份状态挂在了**线程**上——线程 ≠ 执行域:与结构化并发不兼容,跨 `await` 后失效,误用时只有 `preconditionFailure` 崩溃兜底,值逃逸到其它 context 的 scope 时可能解析到**错误的 context** 而非崩溃。修正方向是搬家而非删除(§3.4)。

**P1 – `JSCallbackValue` 可拷贝、handle 为 `public let`**
类型系统层面允许用户复制并存出回调值。arena 只保证"该释放时释放",不保证"释放后无人使用"。QuickJS 场景下逃逸值是悬垂句柄(use-after-free);两引擎下跨 scope 使用都可能把错误 context 传给引擎。

**P1 – 见证类型的临时伪造**
`JSCallbackValue.decode` 与 `getProperty(_ key: borrowing JSPropertyStringKey<E>)` 内部用 `JSInstantContext<E>(handle: ctx)` 临时构造 scope 仅为满足 `borrowHandle(in:)` 签名——push/pop TLS 一次只为类型过关。见证要求的是"能力",不是"某个具体类型",这是 API 形状问题。

**P1 – `JSValue` 的有效性与 home context 隐式耦合**
`JSValue.deinit` 在打包的 home context 里释放引用——"有效值"拖着"有效 context":不保活(context 无 retain),但要求它仍存活。值被存出、context 先死时,deinit 打到已释放的 context 上(悬垂);这一约束没有任何声明式表达,全靠使用纪律。这是"值不能长久存储"的代码级病根,也是 §3.2 将 `JSValue` 反转为本地值的动因。

**P2 – `ScopeCore` 收口未完成**(当前分支未提交内容)
`makeString(from:)` 仍留在 `JSInstantContext` 直写 `core.arena.created`;`JSScope` 无测试覆盖;TODO.md 未立进行中条目。

**P2 – `persist` 无编译期防漏**
忘记 `persist` 的值在 drain 时被释放——行为正确(JSC 无感,QuickJS 无泄漏),但语义上用户拿到的 `JSValue` 会是悬垂。这是 lifetime 依赖转正前无法根治的项,只能靠文档与审查纪律。

**P2 – 统一存储与单协议携带是实现债,不是目标形态**
`JSValueStorageWords` 把 handle+ctx 擦成裸位,是关联类型不能声明 `~Copyable` 年代的隔离手段——存储态永远平凡 Copyable,不被 handle 拷贝性决策绑架;代价是每次 `JSValue.handle` 访问都经 `fromStorageWords` 解码、存储形态与类型系统脱钩、24 字节上限。`JSEngine` 组合单协议把全部静态实现挂在引擎元类型上、`E` 穿透所有公共类型,是同一约束的另一面——能力无法挂在 handle 类型自身,只能经 `E` 传递。SE-0503 之后两条都不再必要(§3.2、Stage 2)。

---

## 3. 目标架构

### 3.1 总览

```
                    ┌──────────────────────────────────────────┐
                    │  执行层:JSContext (actor) + VM executor   │
                    │  执行互斥 + 固定线程身份                    │
                    │  Context = 执行权 + 默认 scope 宿主(§3.6) │
                    └───────────────┬──────────────────────────┘
                                    │ 显式 scope(回调/手动)或默认 scope
                    ┌───────────────▼──────────────────────────┐
                    │  作用域层:ScopeCore 内核                    │
                    │  JSInstantContext(自动) / JSScope(手动)  │
                    │  / JSContext 默认 scope                    │
                    │  = 入口凭证 + arena 释放记账                │
                    └──────┬───────────────────────┬───────────┘
                  工厂创建 │                       │ return / throw(handoff)
                ┌─────────▼─────────┐     ┌───────▼─────────────────────┐
                │ JSValue 协议       │     │ JSCallbackReturn 协议        │
                │ (值级操作;具体类型 │     │ (回调出口 handoff)           │
                │  在 package 内持   │     └─────────────────────────────┘
                │  handle+ctx)       │
                └─────────┬─────────┘
                          │ resolve(handle) → Context.Value?
                ┌─────────▼──────────────────────────────────┐
                │  持久层:JSPersistentHandle 协议              │
                │  identity 绑定,Sendable                    │
                └─────────┬──────────────────────────────────┘
                          │
                ┌─────────▼──────────────────────────────────┐
                │  context 层:JSContext 锚点 + driver 协议      │
                │  JSCContext(GC) / QJSContext(引用计数)       │
                └────────────────────────────────────────────┘
```

### 3.2 本地值:`JSValue` 即作用域值

`JSValue` 从"owning 持久值"反转为**本地值**(V8 文档 `Local<T>` 的对应物):

1. **不持有、不释放**:创建即进入某个 scope 的 arena(回调 scope、手动 `JSScope`、或 context 默认 scope §3.6),释放统一由 `drain()` 记账;`deinit` 不再执行 `releaseReference(in:)`——"值拖着 context"的悬垂病根(§2.5 P1)随 owning 语义一并移除。
2. **以 context 锚定,handle 不外露**:public `JSValue` 协议只声明 `Context`/`InstantContext`,操作以 `InstantContext` 为窗口;引擎的具体值类型在 package 内保存 borrowed handle 与 context handle,作为操作寻址与引擎结果落账的依据(§3.4)。handle 不构成所有权、不参与生命周期(释放权在 arena),也不出现在 public 协议面(3.17 dehandle)。
3. **生命周期声明式严格短于 context**:现阶段以结构化约束表达——`~Copyable`、非 `Sendable`(内部 handle 类型显式标 `~Sendable`,SE-0518,防"成员全 Sendable 的内部 struct 被隐式推断"导致的跨域泄漏)、仅可从 scope 见证工厂构造、回调签名全程 `borrowing`、同步 scope 的构造与值操作标注 `noasync`(SE-0340)。"窗口内无挂起点"的可靠编码是**同步闭包 confinement**——闭包非 async,`await` 词法上不可达;`noasync` 的浅检查语义(经同步包装可绕)恰好使"同步闭包路线 == 唯一合法路线"。`@lifetime` 转正后升级为编译期声明:显式 scope 值标 `@lifetime(borrow scope)`,默认 scope 值标 `@lifetime(copy context)`(Stage 5)。**不采用**保活(值 retain context)或运行时检测(TLS/断言)作为手段。`JSScope` 的公共构造面据此收敛(2026-11-23):`init(handle:)`/`open()` 为 `package`,公共面只有 actor 隔离工厂 `JSContext.makeScope()`,类型为 `~Copyable + ~Sendable`——非 Sendable 使工厂结果跨不出 actor 边界,见证所在的 VM 线程由构造面保证。
4. **`JSCallbackValue` 收敛并入**:其"作用域值"角色与本地值 `JSValue` 重合,终态统一为一个类型(过渡路径与命名见 §7);`~Copyable` 化与 handle 收敛(`package`)是 Stage 1 的第一步——`JSFunctionCallback` 与 `ScopeCore` 工厂签名已全程 `borrowing`,拷贝性当前并未被依赖。

**为什么现阶段不做 `~Escapable`**:那是本地值的终态形态,但依赖 `@lifetime` 的工厂签名才能检查;特性未转正前,`~Escapable` 值无法合法地作为工厂返回值使用(闭包路径还会丢失依赖信息)。演进路径见 Stage 5。

**存储形态与 handle 拆分**:引擎的具体本地值类型在 package 内直接以存储属性持有 `handle + ContextHandle`——两者都是 Copyable 的身份/借用 token,复制无副作用(非拥有)。public `JSValue` 协议不声明这两个类型,只在具体类型上保留。`~Copyable` 不落在借用侧,而落在所有权载体 `OwnedValueHandle` 上(创建结果、arena 元素、handoff),由此构成三层约束栈,每层用最合适的维度:

```
owning handle 层   OwnedValueHandle: ~Copyable     ← 防 QuickJS 双 free(所有权载体)
值层              借用 handle(Copyable)直接存储   ← 身份 token,存储回归类型系统
scope 层          同步值 Stage 5 起 Copyable + ~Escapable + @lifetime(替换 ~Copyable);
                   默认 scope 值 Copyable + 非 Sendable
```

`JSValueStorageWords` 擦除、逐访问 `fromStorageWords` 解码、24 字节上限全部退役——那是关联类型不能声明 `~Copyable` 年代的隔离手段(§2.5 P2)。

### 3.3 见证协议化:消灭临时伪造 scope

引入内部见证协议(而非具体类型)承载 `borrowHandle(in:)` 等签名:

```swift
// 引擎无关、core package 内部;成员类型都是所属 context 的 handle/值类型
package protocol JSScopeWitness: JSValueScope, ~Copyable {
  associatedtype ContextHandle: JSContextRuntimeDriver
  var driverContextHandle: ContextHandle { get }
  var scopeFrame: ScopeFrame<ContextHandle> { get }
  func makeValue(handle: ContextHandle.ValueHandle) -> Value
}
// JSInstantContext 与 JSScope 均符合;JSPropertyStringKey/JSPreparedScript 的
// witness 版 borrowHandle(in:) 改收 JSScopeWitness,消除 decode/getProperty 内部的
// 临时 scope 构造。public JSValueScope 在 3.17 后已没有 handle 成员。
```

`JSContextDataStorageBox` 等 context 附属设施同样改收 handle,不再要求 scope 类型。

### 3.4 作用域栈:ambient 从线程迁到 context

**V8 对证**:V8 的 HandleScope 数据(`handle_scope_data`)挂在 isolate 上,不是线程 TLS——API 显式传 isolate,handle 落进"当前 scope"由栈顶隐式解析,栈是 isolate 内部状态。ambience 撑得住的前提是 isolate 单线程进入;我们把同一份状态挂到 `Thread.threadDictionary` 上才是病根(§2.5 P0)。

**ambient 不能删,只能搬家。** 两个硬理由:

1. 引擎驱动的重入没有显式通道:回调 A 调 `value.call(...)` 触发 JS 再触发回调 B,B 的 scope 由引擎 trampoline 建立,不存在"A 把 scope 传给 B"的路径——scope 的建立天然隐式,只能靠栈纪律;
2. 深层创建无法显式穿参:V8 允许 isolate 内任何代码随时创建值落进当前 scope;若每个操作都以 scope 为键,任何想创建值的 helper 都得把 scope 一路穿下去——不是引擎世界的形状。

**目标形态:**

- **栈挂在 context 上**:per-context 作用域栈放入 context 侧挂存储(`JSContextDataStorageBox` 同机制);`TLSCallbackStack`(`Thread.threadDictionary`)整体退役。执行由 actor/executor 串行化,栈只被 JS 线程触碰,无并发问题;
- **栈底 = 默认 scope**(§3.6,V8 isolate 常驻初始 HandleScope 的同构物):context 建立时压入,deinit 时最后弹出 drain;任何时刻栈顶至少是默认 scope——"没有显式 scope 时创建落在哪"不再是问题,`persist` 到默认 scope = 移到栈底 arena(Stage 3 填充栈底;Stage 1-2 栈内仅临时 scope,行为同现状);
- **操作以 context 为键**:值操作在引擎具体类型内部用 package 的 context handle 寻址(§3.2 第 2 点),public 操作面保持"方法在值上"并只收 `InstantContext`;引擎返回的新 handle 按该 context 栈顶落账;
- **工厂按接收者落账**:scope 接收者(`JSInstantContext`/`JSScope`)上的工厂直接 append 到接收者自己的 arena——接收者即目标,嵌套时持有外层 scope 仍可显式落外层,不劣于 V8 的栈顶解析;
- **scope 的公共职责收敛为两件事**:RAII 生命周期边界 + 合法入口能力凭证(回调签名保留 `borrowing JSInstantContext`,它是"当前栈顶凭证 + ctx 载体"),不再逐操作穿引。原方案 A(值方法加 `in:` 参数)/方案 B(操作上收到 scope)均作废;
- **嵌套契约(显式成文)**:回调 B 中可使用回调 A 创建的值——同 context、A 的 arena 未关即合法,V8"外层 HandleScope 的 Local 可在内层使用"的同构物。

### 3.5 持久层:可恢复 handle(唯一长期存储形态)

值不能长久存储(§2.5 P1),长期持有的唯一公开形态是**可恢复持久 handle**——`JSPersistentHandle` 协议(具体类型 `JSCPersistentHandle`/`QJSPersistentHandle`)只持有 public `JSPersistentHandleIdentity`,对应 V8 文档 `IsolateLocal<T>`/`ContextLocal<T>` 模型:

**生命周期语义(同 ThreadLocal/AsyncLocal,承接 V8 文档 §3.3):**

- 绑定住在**容器侧**(Context 的 registry),handle 只持 identity;
- handle 可跨线程、跨隔离域传递;解析经 `JSContext.resolve` 或 `JSInstantContext`/`JSScope.resolve` 进行(scope 侧标 `noasync`),恢复产物是本地视图(进入接收方 arena);
- 容器消亡或绑定不存在 → 解析返回 `nil`,而非悬垂——handle 不保活 context,context 死亡也不留悬垂 handle;
- 绑定粒度最终采用 `ContextLocal`(context 级,同 runtime 多 context 各自绑定),设计论证见 `docs/PERSISTENT_HANDLE_DESIGN.md` §6。

**目标场景**(V8 文档 §10.1 表映射):宿主内建函数与构造函数缓存的稳定身份、Native 对象跨 context 的 JS 包装(同一 Swift 对象在多个 `JSContext` 各有 JS 表示)、JS 提供的长期回调保存、宿主 API 注册表;弱引用作为强度选项(`strength: .weak`),handle 生命周期结束与 JS 对象被 GC 回收是两个独立事件。V8 文档 §10.2 的结论同样成立——`JSFunctionCallback` 是 native 闭包直接持有,临时值走本地值;handle 只承接身份型引用。

**实现要点:**

1. registry 挂 context 级;identity 采用 public `JSPersistentHandleIdentity`(`registry` + `slot` + `generation`),支持槽位回收与失效防误命中;
2. handle 为引用计数对象,最后一个 owner 释放时经 **VM executor 调度**清理对应绑定——不允许在任意线程直接操作引擎;
3. handle 自身不暴露任何 JS 操作——恢复访问必须经 context/scope 的值级入口(内部经 package 的 scope witness),与"持有不授权访问"一致。

设计工作清单即 V8 文档 §12 各未决问题在本库语境的落地:handle 所有权与自动清理协议、注册表组织、绑定粒度公开面、大量短生命周期 handle 的性能(§7、Stage 4)。

### 3.6 Context 与 Scope 分离:默认 scope

从 V8 API 与典型设计引伸:JSContext(执行权与生命周期宿主)与 Scope(值生命周期窗口)是两个概念,**Context 具有或者就是一个默认 scope**:

- `JSContext` 持有一个 context 级默认 scope(一个长存 `ScopeCore`,走 `explicitRoots` 策略 §3.7),**即 context 作用域栈的栈底**(§3.4):context 建立时压入、deinit 时最后弹出 drain,QuickJS 释放配平与 JSC unprotect-on-drain 由它兜底;
- actor 方法中的值工厂(`makeString` 等)落入默认 scope:产物在 context 存续期内有效(经显式根化,§3.7)、可在同一 actor 的后续调用与 `await` 之间使用,但不可离开 actor(非 `Sendable`)——保持现有 `JSContext` 公共 API 的工效不变;
- 显式 scope(回调 `JSInstantContext`、手动 `JSScope`)是更短的嵌套窗口,用于回调与临时批量创建;默认 scope 是便利层,不是纪律的替代——**提前回收的边界(Stage 3 修正)**:显式 scope 只能提前回收其工厂产物与 persist 进它的值;经公共签名逃逸的 `JSValue` 结果(getProperty/call/evaluateScript/host object 等)一律锚默认 scope,到 context deinit 才回收,长寿命 context 会累积(JSC protect/QuickJS 引用)——默认 scope 的提前回收/compact API 为登记在案的后续项(`TODO.md` §2.2);
- 两类 scope 共享同一 `ScopeCore` 内核与 arena 记账,无第二套生命周期规则。

### 3.7 根化策略:同步 scope 与异步 scope

根域差异(§2.4)决定 scope 需要两种根化行为。`ScopeCore` 以编译期策略参数承载,**实现一份,行为分派**:

```
ScopeCore<ContextHandle, Rooting>  ← 单一实现,Rooting 为编译期策略(空类型标签)
  ├── implicitStackRoots       ← 同步 scope:arena 只记账不根化
  │     JSC: 白嫖保守栈扫描(现状零成本);QuickJS: 创建即持计数,策略恒等
  └── explicitRoots            ← 默认/异步 scope:protect-on-add / unprotect-on-drain
        JSC: JSValueProtect / JSValueUnprotect(arena 在堆存储,必须显式根);
        QuickJS: 恒等(创建已持计数)
```

- **同步 scope**(`JSInstantContext`/`JSScope`):构造与值操作标 `noasync`——值的有效性绑定"在栈上"的隐式根域,JSC 语义要求不得跨挂起点,标注把纪律升格为编译期门禁;
- **默认 scope**(§3.6):arena 活在 actor 的**堆**存储里,JSC 值入 arena 必须 protect-on-add——不加则 JSC 值不跨任何 `await` 也随时可被 GC 收走;QuickJS 无此需求。这是 Stage 3 的硬约束;
- **异步 scope**(异步桥接预留,完整设计另行):未来异步宿主注册引入,不标 `noasync`,值可跨 `await`(同 actor 内),drain 在 async 函数尾。其出口语义不是 `JSCallbackReturn` handoff,而是 resolve 进 promise(V8 文档 §6.2 模式:bridge 运行时持有 resolver,Swift 任务在 VM executor 恢复后结算)——从 resolve 到 promise settle 之间值活在引擎 promise 机制里,天然需要显式根,`explicitRoots` 已覆盖,无需额外机制。公共面用两个名字还是一个类型两个入口,随异步桥接立项定案;core 层永远一份实现;
- 策略差异**只在 JSC 上有实际行为**(QuickJS 恒等;V8 模型的 handle block 本就是显式根,亦恒等)——引擎无关层只暴露 policy 钩子,JSC 细节不外漏。

同步路径保留零成本白嫖,默认/异步路径付 protect 成本,且成本只出现在必须付的地方。

### 3.8 并发与异步边界

维持三条既有约束并写入测试:

1. **显式(同步)scope 不跨 `await`**:V8 文档 §6.3 同款结论;引擎级依据是 §2.4 根域规则——JSC 未根值随帧入堆而脱根,V8 模型/QuickJS 上跨挂起点本身安全,API 取交集换单一规则。回调与手动 scope 在同步窗口内 drain;
2. **执行互斥由 actor 保证,与值生命周期无关**,两层不得互相替代;
3. **专用线程 executor 语义保持不变**(实现于 2026-11-23 换为 `ThreadAffinityExecutor` 库的 `DedicatedThreadExecutor`,见 `docs/PERSISTENT_HANDLE_DESIGN.md` §2.4 末)——它是两引擎线程约束的执行基础,未来 Promise 桥接(异步回调恢复到 JS 线程)也复用它,不在本重构范围内。Swift `await` 的语境分层:隔离域(语言保证必回)/ 串行 executor(actor 保证)/ OS 线程(语言不保证,由本 executor 补齐);取消为协作式,帧清理发生在原隔离域,无 C++ 式异线程析构。executor 已覆盖引擎侧线程语义,scope 侧约束的依据是根域(§3.7)而非线程。

---

## 4. Swift 6.4 能力对齐

### 4.1 现在可用(可进入实现)

| 能力 | 来源 | 对本仓库的意义 |
|---|---|---|
| 关联类型 `~Copyable` 约束 | SE-0503(6.4 转正) | `OwnedValueHandle: ~Copyable` 可经协议表达(QuickJS 双 free 防护精确落在所有权载体);driver 要求可挂到关联类型自身,解锁 god-protocol 分解与值层直接存储(§3.2、Stage 2);这些 driver 协议在 3.17 后均为 package |
| `Equatable`/`Hashable`/`Optional`/`Result` 等不再强制 `Copyable`/`Escapable` | SE-0499(6.4 转正) | `JSValueManualReferenceCountedHandle: Hashable` 与 handle 不可拷贝化不再冲突;`JSResult<V>` 对 `~Copyable` payload 的支持面扩大 |
| 显式 `~Sendable`(压制推断的 `Sendable` 一致性) | SE-0518(6.4 转正) | 内部 handle 类型显式钉死非 Sendable,防"成员全 Sendable 的内部 struct 被隐式推断"导致的跨域泄漏;与 Stage 2 的 `~Copyable` 配套 |

**拆分的连锁影响(实现前必须评估)**:`~Copyable` 只落在所有权载体上——创建结果(+1)、arena 数组元素、`JSCallbackReturn` handoff、driver 所有权转移签名改走 `OwnedValueHandle`(`borrowing`/`consuming` 语义);借用侧 `ValueHandle` 保持 Copyable,引擎的具体值类型(`JSCValue`/`QJSValue`/`JSC*CallbackValue`/`QJS*CallbackValue`)在 package 内直接以存储属性持有 `handle + ContextHandle`(public 协议自 3.17 起不再声明它们),`JSValueStorageWords` 与逐访问解码整体删除。这是 Stage 2 的主体工作量,收益是 QuickJS 双 free 防护精确落在所有权点,且值层存储回归类型系统。

### 4.2 实验可用(不进公共 API)

`@_lifetime` 标注(`-enable-experimental-feature Lifetimes`,Pitch #3 尚未进入评审)。约束结论:

- **工厂标注可行**:`ScopeCore` 工厂签名 `@_lifetime(borrow scope) → JSCallbackValue` 在实验 flag 下可验证,是未来 `~Escapable` 化的前置;
- **闭包签名不可行**:`JSFunctionCallback` 是闭包,依赖信息必在闭包边界丢失(Pitch #2 讨论中 parser combinator 案例即此),Joe Groff 的替代方案是单要求协议——若未来回调类型协议化,`JSFunctionCallback` typealias 可平滑替换;
- **函数子类型缺口**:`copy → borrow` 协变未实现,任何依赖函数类型转换的设计当前都会撞墙。

**结论:arena 与借用签名是可预见周期内的最终防线,不是过渡方案。** 不得以"等 lifetime 转正"为由放松运行时纪律。

### 4.3 演进开关

所有 `@lifetime` 实验代码用编译条件隔离在 `#if canImport(...)` / 自定义编译标志之后,只存在于实验 target 或分支,公共 target 不启用实验 flag。

---

## 5. 分阶段实施计划

每阶段开始前在 `TODO.md` 立进行中条目,完成后打勾并补说明;每阶段收尾跑全量 `swift test` + 对改动 `.swift` 文件跑 `swift format`。

### Stage 0:`ScopeCore` 收口(当前分支,先行)

- [x] `makeString(from:)` 下沉到 `ScopeCore`(以已借出的 `E.PropertyStringKeyHandle` 为参,`borrowHandle(in:)` 见证留在 `JSInstantContext`);`ScopeArena` 与 `ScopeCore.arena` 收回 `private`,结构性消除直写旁路
- [x] `JSScope` 能力面显式化为语义最小面:不提供 `throw`/`return`/`returnUndefined`(仅 `persist`);`makeString(from:)` 无使用者,暂不暴露
- [x] 补 `JSScope` arena 生命周期测试(open/deinit drain、persist 摘除、未 open 不 push TLS、工厂正常)——`Tests/SwiftJavaScriptTests/JSEngineCoreTypesTests.swift`
- [x] `JSCallbackReturn` 初始化器访问级复核(判据:`package` 的边界是**模块**而非文件——同模块跨文件调用(`JSValueInitializers.swift`)`internal` 即可;桥模块读取的 `handle/isException/isPersistent` 字段维持 `package`;`internal` 是覆盖全部调用方的最窄级别)
- [x] TODO.md 立项登记
- [x] 收尾:JSC 桥 persistent 回调返回补 `JSValueUnprotect` 配平(与 QuickJS 的 isPersistent 引用交接对称,修复既有 protect 泄漏);`JSScope` 文档示例 `let`→`var`;`JSInstantContext.makeSymbol` 维持 `package`(`JSScope.makeSymbol` 属新类型公共设计面,保留 `public`)

### Stage 1:作用域栈迁至 context + 值操作 context 寻址(已完成)

前置:Stage 0 合并。

- [x] per-context 作用域栈:静态 `Mutex` 保护 per-ContextHandle 注册表 `ScopeStackRegistry<ContextHandle>`(方案偏差:未用 storage box——裸 MockContext 测试无 box;帧为 `ScopeCore` 本体,非泛型 `ScopeStackStorage` 持锁 + 泛型注册表做类型恢复,Swift 泛型类型不支持 static 存储属性);**无进程级 current 概念**——`top(of:)` 为 per-context 查询,`activeContext` 单槽在收尾删除(并行互踩根因);`TLSCallbackStack`/`threadDictionary` 零残留
- [x] `JSCallbackValue` 内嵌 `ContextHandle`,全部操作经自带 handle 寻址,ambient 查询零残留
- [x] 值操作面保持"方法在值上";引擎结果 handle 按 context 栈顶落账——`bridgeCallbackResult` 双路径 `track` 到 `top(of:)` 的 arena(含 makeObject/makeArray 异常分支),无打开 scope 时 preconditionFailure;修复 QuickJS 值操作结果 +1 无释放路径的既有泄漏,`return` 路径 trampoline 的 `JS_DupValue` 假设自此成立
- [x] `JSScopeWitness` 协议落位,`borrowHandle(in:)` 收协议,`getProperty`/`setProperty` 临时构造删除;`decode` 临时构造经裁决排期 Stage 3(`JSValueDecodable` requirement 属转换用户语义面,临时 scope arena 全程为空、正确性无虞)
- [x] `JSCallbackValue` `~Copyable` 化 + handle 收敛 `package`
- [x] 同步 scope 构造与值操作标注 `noasync`;`JSCallbackValue` 全部值操作一并标注,`setData`/`data`/`makePropertyStringKey`/`prepareScript` 以豁免注释明示(非 scope 绑定值操作)
- [x] 嵌套契约测试:引擎级(经 JS 流转,两引擎参数化)+ Mock 级直接用例(同 context 内层 scope 用外层值、结果落内层账)
- [x] "scope 外使用回调值应编译失败":编译期失败无法在 Swift Testing 内断言,负面样例以文档形式保留于 `EngineScopeContractTests.swift`;`~Copyable` 拷贝门禁实测确认
- [x] MockEngine 测试见证同步

### Stage 2:handle 借用/拥有拆分与 driver 协议分解(SE-0503 落地)

前置:Stage 1 稳定;确认最低工具链声明(swift-tools-version 提升到 6.4)可接受。

**A. 借用/拥有拆分与直接存储(已完成):**

- [x] handle 拆为两个类型(占位名,§7):`ValueHandle`(Copyable 借用 token)与 `OwnedValueHandle: ~Copyable`(所有权载体),双协议单向联动(`Owned.Borrowed == Self`——~Copyable 协议不允许指回 Self 的 same-type 约束)。范围边界:创建工厂与 `makeFunctionValueHandle` 返回 owned,值操作签名维持 borrowed(`bridgeCallbackResult` 经 `adopting` 显式升级后 track,全量 owned 化随 B 块重扫);`JSCallbackReturn.handle` 维持 Copyable(§7 问题 2:temporary/exception 是借用、persistent 的 +1 已由 `takeHandle` 交接,随 Stage 3 定案)
- [x] 引擎的具体值类型(`JSCValue`/`QJSValue`/`JSC*CallbackValue`/`QJS*CallbackValue`)在 package 内直接存储 handle+ContextHandle;storage words 三件套删除(Sources/Tests 零残留)。`JSValue` 以 Optional 守卫 + `init(taking:)` 委派式落地(Swift 6.4 禁非平凡可析构泛型的 `discard self`/init 内 `self =`)。public `JSValue`/`JSCallbackValue` 协议在 3.17 后不再声明 handle
- [x] arena 改分块 `UnsafeMutablePointer` 栈(Array 不支持 ~Copyable 元素,实测);persist 摘除放弃创建引用。**【开放】**该放弃在 QuickJS 上净 +1 泄漏(既有问题):两种结算方案均致并行崩溃(释放从未归零的对象首次触发 quickjs finalizer/GC 路径,根因待查),正确修法为 §3.7 Rooting 分派,排期 Stage 3
- [x] backend owned 变体落位(`JavaScriptCoreOwnedValueHandle`/`QuickJSOwnedValueHandle`),trampoline 引用交接逐字面核验;QuickJS 句柄判等升级为全位 identity(tag+完整 union 位比较)
- [x] 双 free 负面样例以文档块+独立探针实测落地(朴素 `let duplicate = owned` 在仅借用使用时被当作重绑定接受,样例须取消耗性使用形态)

**B. driver 协议分解与 context 实例方法化(已完成,与 TODO §1.3 合流):**

- [x] driver 要求实例化到 `ContextHandle`:新增五个 `JSContext*Driver` 协议由各引擎 ContextHandle 遵循,引擎协议保留为描述符(associated types + 生命周期静态),where 同型链接;核心调用点全量迁移,`releaseCreatedHandle`/storage 三方法为**硬 requirement(无默认)**——静默 no-op 默认会让迁移引擎无声泄漏;引擎静态面保留为转发目标(双入口,方法体物理搬移排后续片)
- [x] 值操作签名 owned 化重扫完成:创建工厂 owned、双路径消费 borrowed、单 JSValue 路径(construct/toObject/evaluate 等)裁决维持 borrowed——唯一消费点即约定包装,owned 化零防护增益
- [x] 约束收窄与退役(本轮份额):`SendableMetatype` 全删;`JSValueConversionEngine` 并集别名落位;`JSCallbackValue`/`JSArguments` 本体只约束 handle 面;类系统(JSClass*/ClassBridgeDriver)仍挂完整 `E: JSEngine`,独立 class driver 面与 `JSFunctionCallback` 去引擎参数化排后续。**Source-breaks 四项记录于 `docs/finished/value-management.md`**
- [x] 按 TODO §1.3 合流推进:Slice 2(基础判型/转换)已随本块完成,Slice 3/4(属性访问/回调链路)随后续片

### Stage 3:`JSValue` 本地值化(核心反转)

前置:Stage 1 完成(作用域栈迁移与值操作 context 寻址稳定)。这是本重构的中心阶段。

- [x] **【验收指标·已按 §7.2 定案变更形态】**persist QuickJS +1 泄漏清零 + exception/persistent 借用锚消解(§2.3 开放项):**原定形态**(owned 交接 + 先 retain 后 settle)在实现中被更优方案取代——`JSValue` 非持有化后 arena 即借用锚点,`JSCallbackReturn` 三态一律借用 + 引擎侧 Duplicate(§7.2 定案),`persist` 改创建引用转移。**三项验收全过**:转移语义(重放等价)、ASan 单测轮、ASan 满载并行轮;Mock 释放计数断言恢复结算语义
- [x] `ScopeCore` 引入编译期 `Rooting` 策略参数(§3.7):`ScopeCore<ContextHandle, Rooting>` 编译期参数 + `ScopeFrame<ContextHandle>` 持有 arena 共享同一 context 栈(运行时 bool 投影,单分支);同步 scope 行为零变化
- [x] `JSContext` 默认 scope:`defaultScope: ScopeCore<ContextHandle, JSExplicitRoots>` 压栈底、deinit 最后 drain;`rootOwnedValueHandle`/`unrootOwnedValueHandle` 硬 requirement(JSC `JSValueProtect`/`JSValueUnprotect`,QuickJS 显式恒等);actor 值工厂与**所有逃逸 JSValue 的引擎结果**统一落默认 scope(落当前同步帧会悬垂,代价是到 context deinit 才回收——见 §3.6 修正;后续项登记于 `TODO.md` §2.2)
- [x] `JSValue` 去 owning 语义:`deinit`/`takeHandle`/`retainHandle`/`discard`/`init(taking:)` 删除,handle 为非 Optional 纯身份 token(`init(copying:)` 无副作用视图);根化片曾加的过渡引用已随值反转删除
- [x] `persist` 重定义:创建引用转移(源 `takeFirst` 显式根随摘除解除 → 目标 `track` 重新根化),arena-owned 零 retain/release;borrowed fallback 经 `claimOwnedValueHandle` 认领恰好一次(QuickJS dup/JSC identity);默认目标为栈底帧
- [x] `JSValue`/`JSCallbackValue` 统一评估:**暂不合并**(§7.4 定案)——构造面与 `noasync` 同步窗口契约不同,合并排期 Stage 5 随 `~Escapable`/`@lifetime`
- [x] `JSObject`/converter/宏依赖面迁移完成:converter 经 `anchorEscapingValue` 锚进默认 scope;宏模板改 `borrowHandle`;`releaseArguments` 删除;owning 残留 rg 零命中
- [x] 契约测试:context 先亡 drain 配平(Mock)、跨 `await` 同 actor(两引擎)、嵌套同步 scope、跨隔离域编译失败负面样例(文档块 + 探针实测)

### Stage 4:持久 handle 层(目标能力,设计先行)

前置:Stage 3 完成(本地值语义稳定——`resolve` 的产物是本地值);Stage 2 完成(handle 借用/拥有拆分,避免 registry 存储层二次返工)。设计子任务(纯文档与原型)可与 Stage 1-3 并行启动。

- [x] 设计子文档:`docs/PERSISTENT_HANDLE_DESIGN.md` 定稿并经独立评审修订(§4.3 替换 = invalidate + mint、§4.4 **v1 强绑定**(JSC/QuickJS 均无宿主侧弱引用 API,据此重写"弱引用不阻 GC"验收条——root 跨强制 GC 保活 + QuickJS JS `WeakRef` 释放后不阻 GC,JSC 不测释放后可回收性)、§6.1 `ContextLocal`、槽位 + generation registry、`schedulePersistentCleanup` 经 VM executor)
- [x] core 层实现:`JSPersistentHandle`(identity 化 Sendable,零 JS 操作面)+ `JSPersistentHandleRegistry`(context 数据箱挂载、分块 slab + free list、generation 防误命中);`resolve` 在接收帧上 claim 并 track 进 arena;零后端改动
- [x] 基准测试:`Benchmarks/PersistentHandleBenchmarks` 独立 target,JSC/QuickJS 真实数据 + synthetic 槽位 vs Dictionary(复核员独立复现命中)。选型:维持 slab+free list(chunk 32);`pending` 队列建议 head cursor(尾风险登记);witness 优先 typed `package` 字段(box 查找占 resolve 40-45%)
- [x] 跨引擎测试:契约测试双引擎参数化 + QuickJS 单引擎 WeakRef 用例;Mock 侧精确计数全套;哨兵全部状态化(空 ping 实测被优化为非跳转调用);VM 上第二 context 创建当时经存活 context 窗口规避线程问题(线程收口后不再需要);双 close 幂等、close 后 resolve nil、bare-context 负面样例补齐。遗留测试缺口(§8.1-10 settling 计数器、§8.2-4 QuickJS 内存基线、§8.3 隔离断言/迟到泵)与 `pending` 队列尾风险已于 2026-11-23 闭环(head cursor 化后基准复跑双引擎斜率不变);此前待定的两项(外部清箱线程归属、`JSScope` 公共面收紧)按裁决随后闭环,见下条
- [x] 执行器重构与清箱路由(2026-11-23):执行器换为 `ThreadAffinityExecutor` 库的 `DedicatedThreadExecutor`,闭包投递为 `Task.detached(executorPreference:)`;`installContextDataStorageBox` 对托管 context 路由到 VM 线程;`JSScope` 构造面收敛为 `JSContext.makeScope()`。依据与实现落点见 `docs/PERSISTENT_HANDLE_DESIGN.md` §2.4 末与 §3.5;完成项归档于 `docs/finished/value-management.md`
- [x] 线程归属收口(2026-11-23):`JSContext.init`、`JSVirtualMachine` 的 runtime 建/释、`JSPreparedScript`/`JSPropertyStringKey` 的析构全部路由到 VM 线程;"引擎调用只在 VM 线程"(§0.2.3)至此覆盖生命周期两端,仅 `JSClass.deinit` 的 JSC `JSClassRelease` 未路由(登记于 `TODO.md` §2.2)。路由规则见 `docs/PERSISTENT_HANDLE_DESIGN.md` §3.5

### Stage 5:lifetime 依赖转正后的迁移(远期,特性门槛)

前置:`@lifetime` 转正且闭包/函数类型支持依赖标注。本阶段的核心收益正是 §3.2 第 3 点的完全体:**"本地值生命周期严格短于 context"从结构化约束升级为编译期声明**。

- [ ] 本地值**摘除 `~Copyable`**,换上 `Copyable + ~Escapable`(替换关系,非追加——所有权已不构成复制风险,三层约束栈见 §3.2);显式 scope 工厂标 `@lifetime(borrow scope)`,默认 scope 工厂标 `@lifetime(copy context)`
- [ ] 评估 `JSFunctionCallback` 闭包 → 单要求协议(此时协议要求可携带依赖标注)
- [ ] arena 从"正确性保障"降级为"释放记账"(逃逸检查交给编译器,drain 仍负责 QuickJS 释放配平)
- [ ] 重新评估 §2.5 P2 的 `persist` 防漏能否交给编译器

---

## 6. 非目标

1. **不做异步宿主注册 / Promise 桥接**:异步互操作另行设计;但 §3.7 的 `Rooting` 策略与异步 scope 形态已预留,桥接立项时不再动 scope 内核。
2. **不引入 V8 式多 Isolate 并行执行模型**:当前 `JSVirtualMachine` = 单 runtime + 专用线程,多 VM 实例即多 isolate,无需新抽象。
3. **不以搬空 facade 为目标**:维持 TODO §1.4 边界约束,本文档所有改动限于 core 值管理层与必要的 backend 签名配合。
4. **公共 API 不使用实验特性**:§4.2 全部隔离在编译条件后。
5. **不保留值语义的持久面**:长期持有的唯一公开形态是可恢复 handle(§3.5);`JSValue` 的 owning/持久职责随 Stage 3 退役,不做"双轨"。

---

## 7. 未决问题

1. **Stage 1 方案 B 的操作归属粒度**:`call/getProperty` 等全部上收到 scope 后,`JSCallbackValue` 是否还应保留 `handle` 访问给宏插件生成的代码?宏生成模板的改造成本需在 Stage 1 启动前评估。
2. **`JSCallbackReturn.persistent` 与 `JSValue` deinit 的交接**已有测试覆盖;Stage 2 拆分后 `JSCallbackReturn` 改存 `OwnedValueHandle`(`~Copyable`),其按值存储与 `borrowing`/`consuming` 语义随签名审计定论。**Stage 3 定案:不存 owned,维持借用。** 理由:owned 交接原本是为补偿 `JSValue.deinit` 先释放引用、trampoline 后借用的时序缺陷(ASan 已定位);`JSValue` 反转为非持有本地值后,借用锚点由 arena 承担——`persistent` 的锚点是 context 默认 scope,天然长于回调——跨帧所有权转移不再必要。temporary/persistent/exception 三态一律借用,trampoline 给出引擎自有的引用(QuickJS `JS_DupValue`;JSC 无引用会计,不做 protect/unprotect),arena 的引用仍由 drain 结清。锚点取决于值的归属 arena 而非标记本身:context 工厂产物锚默认 scope(天然长于回调),类桥值锚其回调 scope——回调存续期间同样成立。`isPersistent` 因此仅为语义标记,trampoline 不读取它。实现注解见 `JSInstantContext.swift` 的 `JSCallbackReturn` 与两侧 trampoline。
3. **handle 层的所有权与绑定粒度**:引用计数 + 自动清理 vs 显式 invalidate(V8 文档 §12.1 同款问题,初步倾向前者,见 §3.5);`RuntimeLocal` vs `ContextLocal` 的公开面——两引擎堆边界在 runtime 层,但全局对象/构造函数是 context 级差异,绑定粒度随第一版公开哪些待定。
4. **`JSValue`/`JSCallbackValue` 统一与命名**:本地值化后两型角色重合,终态合并为单一类型;"JSValue" 名称保留给本地值(用户语义面不变),"JSCallbackValue" 退役或内部化——Stage 3 定案。**Stage 3 定案:暂不合并,记明理由与后续。** 两型的引擎具体类型此时都是 `handle + ContextHandle` 的非持有视图(public 协议已在 3.17 去掉 handle 成员),但构造面(`JSCallbackValue` 仅 scope 工厂可建 vs `JSValue` 公开初始化器)与操作面(`noasync` 同步窗口 vs 显式 scope/默认 scope 可跨 `await`)不同;此刻合并会放宽回调值构造面并抹掉同步窗口这一契约。合并排期 Stage 5,与 `~Escapable`/`@lifetime` 一同把两种生命周期收进单一类型。现状说明见 `JSCallbackValue` 类型文档。
5. **借用/拥有 handle 的命名与边界**:`ValueHandle`/`OwnedValueHandle` 为占位名;拆分边界(哪些 driver 签名属于所有权转移)随 Stage 2A 签名审计定案。

---

## 8. 结论

本次重构的中心思想:

> **以 `ScopeCore` 为唯一作用域内核,作用域栈挂在 context 上(线程 TLS 退役),栈底为默认 scope;`JSInstantContext`/`JSScope` 是其生命周期包装与入口凭证;`JSValue` 是本地值——不持有、不释放,引擎具体类型在 package 内以 handle + context handle 寻址,public 协议不暴露它们,生命周期以声明式约束严格短于 context;arena 承担 QuickJS 释放配平的运行时事实,根化按 scope 种类分派——同步 scope 白嫖 JSC 隐式栈根、默认/异步 scope 显式根化(§3.7);长期持有的唯一形态是可恢复持久 handle(identity 绑定,解析经 context/scope 的值级入口回到本地值,容器消亡得空而非悬垂)。**

该方案在 Swift 6.4 的能力边界内可完整落地(仅 Stage 5 依赖未转正特性),且与 V8 文档的分层对齐:本地值(`JSValue`)、可恢复持久引用(handle 层)、访问见证(scope)、执行权(actor + 专用线程)各归其位,释放记账作为双引擎现实引入的维度独立存在。

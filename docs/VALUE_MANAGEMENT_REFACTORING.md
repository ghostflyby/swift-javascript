# 值管理架构重构设计

**状态:设计文档(待评审)**
**日期:2026-11**
**关联分支:`scope_arena`**

本文档结合三方面输入,规划 `SwiftJavaScript` core 的值管理架构重构:

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
| 本地值 `Local<T>`(有效性与 Scope 绑定,不存 context) | `JSValue<E>` 重定义为本地值(§3.2):不持有、不释放,可带 `ContextHandle` 仅作便利 |
| 持久引用(持有不授权访问、不保活) | 可恢复持久 handle(`ContextLocal`/`RuntimeLocal`,identity 决定绑定,§3.5) |
| 访问见证(必须经合法上下文恢复 Local) | 值自带 `ContextHandle` 寻址 + context 挂载作用域栈(§3.4) |
| 执行权限(actor / Locker) | `JSContext<E>: actor` + `JSVirtualMachine` 专用线程 executor |

**本仓库新增的第四维:释放记账。** V8 的 Local 生命周期由 HandleScope 在引擎内部管理;本仓库的引擎差异要求 core 自己记账——QuickJS 的 `ValueHandle` 引用计数必须配平(`releaseCreatedHandle` = `JS_FreeValue`),JSC 则由 GC 接管(`releaseCreatedHandle` = no-op)。arena 就是这份记账的载体,它不是可优化项,而是 QuickJS 正确性的运行时事实来源。与之并存的是**根域差异**:JSC 未 Protect 的值靠保守扫描执行线程栈存活,QuickJS 靠与位置无关的引用计数——挂起点把引用帧从栈搬进堆,对 JSC 即脱根(§2.4、§3.7)。

**闭包边界是生命周期信息的断层。** `JSFunctionCallback<E>` 是闭包类型;Swift 6.4 的 lifetime 依赖标注无法出现在闭包签名上(实验性的函数类型语法也存在 copy→borrow 转换未实现等缺口)。因此"回调值不逃逸 scope"这一约束在可预见的工具链周期内无法交给编译器,必须由 `~Copyable` 借用签名 + arena 释放纪律 + 显式提升(`persist`)共同承担。

**设计基准是目标能力清单,不是存量使用。** 本库尚在构建期,任何"当前无人引用"对所有目标能力都成立,不构成排除论据;判断标准只能是:能力是否属于目标 API 面、成本是否匹配、时序是否合理。

**本地值不携带所有权,持久引用不保活。** JS 值的日常形态是本地值:有效性严格短于 context,由声明式约束保证(结构化约束先行,`@lifetime` 转正后编译期化),而不是靠保活 context 或运行时检测。长期存储的唯一形态是可恢复 handle——生命周期语义同 ThreadLocal/AsyncLocal:绑定住在容器(Context/Runtime)侧,持有者只持有 identity,容器消亡后解析返回空而非悬垂。

---

## 2. 现状盘点

### 2.1 值类型分层

| 类型 | 拷贝性 | 生命周期归属 | 说明 |
|---|---|---|---|
| `JSValue<E>` | `~Copyable` | 自持(home context 打包进 24 字节 storage words,deinit 时在 home context 释放) | 持久值;操作走显式 `in context` 参数(操作上下文) |
| `JSCallbackValue<E>` | **可拷贝** | 不自持;创建来源二分:回调参数帧(引擎持有)/ scope 工厂(arena 持有) | 每个操作经 `resolveContext()` 从 TLS 取 context |
| `JSCallbackReturn<E>` | `~Copyable` | 回调出口的 ownership handoff(temporary / persistent / exception 三态) | `persistent` 路径跳过 `JSValue.deinit` 的重复释放 |
| `JSPropertyStringKey<E>` / `JSPreparedScript<E>` | — | context 作用域句柄 | `borrowHandle(in: JSInstantContext<E>)` 强制要求 instant scope 作见证 |

### 2.2 作用域层(`scope_arena` 分支进行中)

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

### 2.3 执行层

- `JSVirtualMachine<E>`:`RuntimeHandle` + 专用线程 `SerialExecutor`——执行线程身份固定,强于普通 actor 的串行保证,满足 JSC/QuickJS 的线程约束(对应 V8 文档"固定 OS 线程"分支)。
- `JSContext<E>: actor`:绑定 VM executor;所有公共操作经 `withInstantContext` 进入同步 scope。**actor 保证执行互斥,scope 保证引用生命周期,二者职责不同且都已存在**——这与 V8 文档 §6.3 的结论一致,本仓库无需改动。

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

### 2.5 现存问题(按优先级)

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
                │ JSValue           │     │ JSCallbackReturn            │
                │ (本地值,借用      │     │ (回调出口 handoff)           │
                │  handle+ctx)     │     └─────────────────────────────┘
                └─────────┬─────────┘
                          │ resolve(in: witness) → JSValue?
                ┌─────────▼──────────────────────────────────┐
                │  持久层:可恢复 handle(ContextLocal /         │
                │  RuntimeLocal,identity 绑定,Sendable)      │
                └─────────┬──────────────────────────────────┘
                          │
                ┌─────────▼──────────────────────────────────┐
                │  引擎层:JSEngine driver 协议                 │
                │  JSC(GC) / QuickJS(引用计数)               │
                └────────────────────────────────────────────┘
```

### 3.2 本地值:`JSValue` 即作用域值

`JSValue` 从"owning 持久值"反转为**本地值**(V8 文档 `Local<T>` 的对应物):

1. **不持有、不释放**:创建即进入某个 scope 的 arena(回调 scope、手动 `JSScope`、或 context 默认 scope §3.6),释放统一由 `drain()` 记账;`deinit` 不再执行 `releaseReference(in:)`——"值拖着 context"的悬垂病根(§2.5 P1)随 owning 语义一并移除。
2. **内嵌 `ContextHandle`,承重而非便利**:本地值的操作以 context 为键,直接使用值自带的 `ContextHandle`(§3.4)——不再逐操作穿引 scope 或 context 参数。它不构成所有权、不参与生命周期(释放权在 arena),但是操作寻址与引擎结果落账的依据。
3. **生命周期声明式严格短于 context**:现阶段以结构化约束表达——`~Copyable`、非 `Sendable`(内部 handle 类型显式标 `~Sendable`,SE-0518,防"成员全 Sendable 的内部 struct 被隐式推断"导致的跨域泄漏)、仅可从 scope 见证工厂构造、回调签名全程 `borrowing`、同步 scope 的构造与值操作标注 `noasync`(SE-0340)。"窗口内无挂起点"的可靠编码是**同步闭包 confinement**——闭包非 async,`await` 词法上不可达;`noasync` 的浅检查语义(经同步包装可绕)恰好使"同步闭包路线 == 唯一合法路线"。`@lifetime` 转正后升级为编译期声明:显式 scope 值标 `@lifetime(borrow scope)`,默认 scope 值标 `@lifetime(copy context)`(Stage 5)。**不采用**保活(值 retain context)或运行时检测(TLS/断言)作为手段。
4. **`JSCallbackValue` 收敛并入**:其"作用域值"角色与本地值 `JSValue` 重合,终态统一为一个类型(过渡路径与命名见 §7);`~Copyable` 化与 handle 收敛(`package`)是 Stage 1 的第一步——`JSFunctionCallback` 与 `ScopeCore` 工厂签名已全程 `borrowing`,拷贝性当前并未被依赖。

**为什么现阶段不做 `~Escapable`**:那是本地值的终态形态,但依赖 `@lifetime` 的工厂签名才能检查;特性未转正前,`~Escapable` 值无法合法地作为工厂返回值使用(闭包路径还会丢失依赖信息)。演进路径见 Stage 5。

**存储形态与 handle 拆分**:本地值直接以存储属性持有 `handle + ContextHandle`——两者都是 Copyable 的身份/借用 token,复制无副作用(非拥有)。`~Copyable` 不落在借用侧,而落在所有权载体 `OwnedValueHandle` 上(创建结果、arena 元素、handoff),由此构成三层约束栈,每层用最合适的维度:

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
// 引擎无关、core 内部
protocol JSScopeWitness<E: JSEngine>: ~Copyable {
  var driverContextHandle: E.ContextHandle { get }
}
// JSInstantContext 与 JSScope 均符合;JSPropertyStringKey/JSPreparedScript 的
// borrowHandle(in:) 改收 JSScopeWitness,消除 decode/getProperty 内部的
// 临时 JSInstantContext 构造。
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
- **操作以 context 为键**:值操作用值自带的 `ContextHandle` 寻址(§3.2 第 2 点),操作面保持"方法在值上";引擎返回的新 handle 按该 context 栈顶落账;
- **工厂按接收者落账**:scope 接收者(`JSInstantContext`/`JSScope`)上的工厂直接 append 到接收者自己的 arena——接收者即目标,嵌套时持有外层 scope 仍可显式落外层,不劣于 V8 的栈顶解析;
- **scope 的公共职责收敛为两件事**:RAII 生命周期边界 + 合法入口能力凭证(回调签名保留 `borrowing JSInstantContext`,它是"当前栈顶凭证 + ctx 载体"),不再逐操作穿引。原方案 A(值方法加 `in:` 参数)/方案 B(操作上收到 scope)均作废;
- **嵌套契约(显式成文)**:回调 B 中可使用回调 A 创建的值——同 context、A 的 arena 未关即合法,V8"外层 HandleScope 的 Local 可在内层使用"的同构物。

### 3.5 持久层:可恢复 handle(唯一长期存储形态)

值不能长久存储(§2.5 P1),长期持有的唯一公开形态是**可恢复持久 handle**——一个只持有 identity 的 `Sendable` 类型(命名待定,`JSPersistentHandle` / `JSRef` 候选),对应 V8 文档 `IsolateLocal<T>`/`ContextLocal<T>` 模型:

**生命周期语义(同 ThreadLocal/AsyncLocal,承接 V8 文档 §3.3):**

- 绑定住在**容器侧**(Context 或 Runtime 的 registry),handle 只持 identity;
- handle 可跨线程、跨隔离域传递;解析 `resolve(in: witness) -> JSValue?` 在合法 scope 见证下进行,恢复产物是本地值(进入当前 arena);
- 容器消亡或绑定不存在 → 解析返回 `nil`,而非悬垂——handle 不保活 context,context 死亡也不留悬垂 handle;
- 绑定的存储粒度是设计决策点:`RuntimeLocal`(VM 级,对应两引擎堆边界 §2.4)vs `ContextLocal`(context 级,同 runtime 多 context 各自绑定),见 §7。

**目标场景**(V8 文档 §10.1 表映射):宿主内建函数与构造函数缓存的稳定身份、Native 对象跨 context 的 JS 包装(同一 Swift 对象在多个 `JSContext` 各有 JS 表示)、JS 提供的长期回调保存、宿主 API 注册表;弱引用作为强度选项(`strength: .weak`),handle 生命周期结束与 JS 对象被 GC 回收是两个独立事件。V8 文档 §10.2 的结论同样成立——`JSFunctionCallback` 是 native 闭包直接持有,临时值走本地值;handle 只承接身份型引用。

**实现要点:**

1. registry 挂容器级(`RuntimeLocal` → VM 级);identity 采用整数槽位 + generation(`index: UInt32, generation: UInt32`),支持槽位回收与失效防误命中;
2. handle 为引用计数对象,最后一个 owner 释放时经 **VM executor 调度**清理对应绑定——不允许在任意线程直接操作引擎;
3. handle 自身不暴露任何 JS 操作——恢复访问必须经 scope 见证,与"持有不授权访问"一致。

设计工作清单即 V8 文档 §12 各未决问题在本库语境的落地:handle 所有权与自动清理协议、注册表组织、绑定粒度公开面、大量短生命周期 handle 的性能(§7、Stage 4)。

### 3.6 Context 与 Scope 分离:默认 scope

从 V8 API 与典型设计引伸:JSContext(执行权与生命周期宿主)与 Scope(值生命周期窗口)是两个概念,**Context 具有或者就是一个默认 scope**:

- `JSContext` 持有一个 context 级默认 scope(一个长存 `ScopeCore`,走 `explicitRoots` 策略 §3.7),**即 context 作用域栈的栈底**(§3.4):context 建立时压入、deinit 时最后弹出 drain,QuickJS 释放配平与 JSC unprotect-on-drain 由它兜底;
- actor 方法中的值工厂(`makeString` 等)落入默认 scope:产物在 context 存续期内有效(经显式根化,§3.7)、可在同一 actor 的后续调用与 `await` 之间使用,但不可离开 actor(非 `Sendable`)——保持现有 `JSContext` 公共 API 的工效不变;
- 显式 scope(回调 `JSInstantContext`、手动 `JSScope`)是更短的嵌套窗口,用于回调与临时批量创建;默认 scope 是便利层,不是纪律的替代——需要精确释放时仍应使用显式 scope;
- 两类 scope 共享同一 `ScopeCore` 内核与 arena 记账,无第二套生命周期规则。

### 3.7 根化策略:同步 scope 与异步 scope

根域差异(§2.4)决定 scope 需要两种根化行为。`ScopeCore` 以编译期策略参数承载,**实现一份,行为分派**:

```
ScopeCore<E, Rooting>          ← 单一实现,Rooting 为编译期策略(空类型标签)
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
3. **专用线程 executor 保持不变**——它是两引擎线程约束的执行基础,未来 Promise 桥接(异步回调恢复到 JS 线程)也复用它,不在本重构范围内。Swift `await` 的语境分层:隔离域(语言保证必回)/ 串行 executor(actor 保证)/ OS 线程(语言不保证,由本 executor 补齐);取消为协作式,帧清理发生在原隔离域,无 C++ 式异线程析构。executor 已覆盖引擎侧线程语义,scope 侧约束的依据是根域(§3.7)而非线程。

---

## 4. Swift 6.4 能力对齐

### 4.1 现在可用(可进入实现)

| 能力 | 来源 | 对本仓库的意义 |
|---|---|---|
| 关联类型 `~Copyable` 约束 | SE-0503(6.4 转正) | `OwnedValueHandle: ~Copyable` 可经协议表达(QuickJS 双 free 防护精确落在所有权载体);driver 要求可挂到关联类型自身,解锁 god-protocol 分解与值层直接存储(§3.2、Stage 2) |
| `Equatable`/`Hashable`/`Optional`/`Result` 等不再强制 `Copyable`/`Escapable` | SE-0499(6.4 转正) | `JSValueManualReferenceCountedHandle: Hashable` 与 handle 不可拷贝化不再冲突;`JSResult<V>` 对 `~Copyable` payload 的支持面扩大 |
| 显式 `~Sendable`(压制推断的 `Sendable` 一致性) | SE-0518(6.4 转正) | 内部 handle 类型显式钉死非 Sendable,防"成员全 Sendable 的内部 struct 被隐式推断"导致的跨域泄漏;与 Stage 2 的 `~Copyable` 配套 |

**拆分的连锁影响(实现前必须评估)**:`~Copyable` 只落在所有权载体上——创建结果(+1)、arena 数组元素、`JSCallbackReturn` handoff、driver 所有权转移签名改走 `OwnedValueHandle`(`borrowing`/`consuming` 语义);借用侧 `ValueHandle` 保持 Copyable,`JSValue`/`JSCallbackValue` 直接以存储属性持有 `handle + ContextHandle`,`JSValueStorageWords` 与逐访问解码整体删除。这是 Stage 2 的主体工作量,收益是 QuickJS 双 free 防护精确落在所有权点,且值层存储回归类型系统。

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

- [x] per-context 作用域栈:静态 `Mutex` 保护 per-ContextHandle 注册表 `ScopeStackRegistry<E>`(方案偏差:未用 storage box——裸 MockContext 测试无 box;帧为 `ScopeCore` 本体,非泛型 `ScopeStackStorage` 持锁 + 泛型注册表做类型恢复,Swift 泛型类型不支持 static 存储属性);**无进程级 current 概念**——`top(of:)` 为 per-context 查询,`activeContext` 单槽在收尾删除(并行互踩根因);`TLSCallbackStack`/`threadDictionary` 零残留
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
- [x] `JSValue`/`JSCallbackValue` 直接存储 handle+ContextHandle;storage words 三件套删除(Sources/Tests 零残留)。`JSValue` 以 Optional 守卫 + `init(taking:)` 委派式落地(Swift 6.4 禁非平凡可析构泛型的 `discard self`/init 内 `self =`)
- [x] arena 改分块 `UnsafeMutablePointer` 栈(Array 不支持 ~Copyable 元素,实测);persist 摘除放弃创建引用。**【开放】**该放弃在 QuickJS 上净 +1 泄漏(既有问题):两种结算方案均致并行崩溃(释放从未归零的对象首次触发 quickjs finalizer/GC 路径,根因待查),正确修法为 §3.7 Rooting 分派,排期 Stage 3
- [x] backend owned 变体落位(`JavaScriptCoreOwnedValueHandle`/`QuickJSOwnedValueHandle`),trampoline 引用交接逐字面核验;QuickJS 句柄判等升级为全位 identity(tag+完整 union 位比较)
- [x] 双 free 负面样例以文档块+独立探针实测落地(朴素 `let duplicate = owned` 在仅借用使用时被当作重绑定接受,样例须取消耗性使用形态)

**B. driver 协议分解与 context 实例方法化(已完成,与 TODO §1.3 合流):**

- [x] driver 要求实例化到 `ContextHandle`:新增五个 `JSContext*Driver` 协议由各引擎 ContextHandle 遵循,引擎协议保留为描述符(associated types + 生命周期静态),where 同型链接;核心调用点全量迁移,`releaseCreatedHandle`/storage 三方法为**硬 requirement(无默认)**——静默 no-op 默认会让迁移引擎无声泄漏;引擎静态面保留为转发目标(双入口,方法体物理搬移排后续片)
- [x] 值操作签名 owned 化重扫完成(逐签名表见 TODO §2.4):创建工厂 owned、双路径消费 borrowed、单 JSValue 路径(construct/toObject/evaluate 等)裁决维持 borrowed——唯一消费点即约定包装,owned 化零防护增益
- [x] 约束收窄与退役(本轮份额):`SendableMetatype` 全删;`JSValueConversionEngine` 并集别名落位;`JSCallbackValue`/`JSArguments` 本体只约束 handle 面;类系统(JSClass*/ClassBridgeDriver)仍挂完整 `E: JSEngine`,独立 class driver 面与 `JSFunctionCallback` 去引擎参数化排后续。**Source-breaks 四项已登记(TODO §2.4)**
- [x] 按 TODO §1.3 合流推进:Slice 2(基础判型/转换)已随本块完成,Slice 3/4(属性访问/回调链路)随后续片

### Stage 3:`JSValue` 本地值化(核心反转)

前置:Stage 1 完成(作用域栈迁移与值操作 context 寻址稳定)。这是本重构的中心阶段。

- [ ] **【验收指标】**`JSCallbackReturn` exception/persistent 路径 owned 交接 + persist QuickJS +1 泄漏清零(§2.3 开放项,ASan 已定位机制:借用缺锚):修复落地后**重放结算语义**(先 `retainReference` 后 settle)并以 `swift test --sanitize=address` 全量通过(单测与满载并行各一轮),Mock 释放计数断言恢复结算语义的精确计数——三项全过方可关闭开放项
- [ ] `ScopeCore` 引入编译期 `Rooting` 策略参数(§3.7):同步 scope 维持 `implicitStackRoots`(JSC 白嫖栈扫描),默认 scope 走 `explicitRoots`
- [ ] `JSContext` 增加默认 scope(§3.6):context 级长存 `ScopeCore`(`explicitRoots`),deinit 时 drain;actor 值工厂改落默认 scope;**JSC 值入 arena 必须 protect-on-add、drain 时 unprotect**(§3.7 硬约束;QuickJS 策略恒等,`releaseCreatedHandle` 语义不变)
- [ ] `JSValue` 去 owning 语义:移除 `deinit` 的 `releaseReference(in:)` 与 home-context 释放职责;存储已是直接属性(handle+ctx,Stage 2 完成)
- [ ] `persist` 重定义:从"提升为 owning 值"改为"移入指定 scope 的 arena"(回调 scope → 默认 scope 或手动指定);`JSCallbackReturn` 的 temporary/persistent handoff 语义不变(出口交给引擎)
- [ ] `JSValue`/`JSCallbackValue` 统一评估:合并为单一本地值类型或保留两型共享 `ScopeCore`(§7),连同命名一并定案
- [ ] `JSObject`/converter/宏生成模板对 `JSValue` owning 语义的依赖面清点与迁移
- [ ] 测试:context 先于值消亡不再是悬垂 deinit(QuickJS 下默认 scope drain 配平);值跨 `await`(同 actor)可用、跨隔离域编译失败

### Stage 4:持久 handle 层(目标能力,设计先行)

前置:Stage 3 完成(本地值语义稳定——`resolve` 的产物是本地值);Stage 2 完成(handle 借用/拥有拆分,避免 registry 存储层二次返工)。设计子任务(纯文档与原型)可与 Stage 1-3 并行启动。

- [ ] 设计子文档:handle 所有权(引用计数 + 自动清理 vs 显式 invalidate)、绑定粒度(`RuntimeLocal` vs `ContextLocal` 的公开面)、注册表组织(Dictionary vs 整数槽位 + generation)、失效通知路径
- [ ] core 层实现可恢复 handle + 容器级 registry;恢复路径按 §3.5:handle → scope 见证 → 本地值(进当前 arena)
- [ ] 基准测试(对应 V8 文档 §10.3/§12.4):handle 分配/释放、恢复、注册表查找、大量 handle 同时失效,与默认 scope 直接持有对比——基准结论用于校准实现选型(槽位 vs Dictionary),不是"是否做"的判据
- [ ] 跨引擎测试:跨 context 解析、无绑定/容器消亡返回空、弱引用不阻 GC、handle 析构自动清理(经 VM executor)、Sendable 跨隔离域传递

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
2. **`JSCallbackReturn.persistent` 与 `JSValue` deinit 的交接**已有测试覆盖;Stage 2 拆分后 `JSCallbackReturn` 改存 `OwnedValueHandle`(`~Copyable`),其按值存储与 `borrowing`/`consuming` 语义随签名审计定论。
3. **handle 层的所有权与绑定粒度**:引用计数 + 自动清理 vs 显式 invalidate(V8 文档 §12.1 同款问题,初步倾向前者,见 §3.5);`RuntimeLocal` vs `ContextLocal` 的公开面——两引擎堆边界在 runtime 层,但全局对象/构造函数是 context 级差异,绑定粒度随第一版公开哪些待定。
4. **`JSValue`/`JSCallbackValue` 统一与命名**:本地值化后两型角色重合,终态合并为单一类型;"JSValue" 名称保留给本地值(用户语义面不变),"JSCallbackValue" 退役或内部化——Stage 3 定案。
5. **借用/拥有 handle 的命名与边界**:`ValueHandle`/`OwnedValueHandle` 为占位名;拆分边界(哪些 driver 签名属于所有权转移)随 Stage 2A 签名审计定案。

---

## 8. 结论

本次重构的中心思想:

> **以 `ScopeCore` 为唯一作用域内核,作用域栈挂在 context 上(线程 TLS 退役),栈底为默认 scope;`JSInstantContext`/`JSScope` 是其生命周期包装与入口凭证;`JSValue` 是本地值——不持有、不释放、自带承重 `ContextHandle`,生命周期以声明式约束严格短于 context;arena 承担 QuickJS 释放配平的运行时事实,根化按 scope 种类分派——同步 scope 白嫖 JSC 隐式栈根、默认/异步 scope 显式根化(§3.7);长期持有的唯一形态是可恢复持久 handle(identity 绑定,解析经 scope 见证回到本地值,容器消亡得空而非悬垂)。**

该方案在 Swift 6.4 的能力边界内可完整落地(仅 Stage 5 依赖未转正特性),且与 V8 文档的分层对齐:本地值(`JSValue`)、可恢复持久引用(handle 层)、访问见证(scope)、执行权(actor + 专用线程)各归其位,释放记账作为双引擎现实引入的维度独立存在。

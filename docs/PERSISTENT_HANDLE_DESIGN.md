# 持久 handle 层设计(`JSPersistentHandle`)

**状态:已实现(Stage 4;S1–S15 已切换到协议 + 具体类型;§11 为基准实测)**
**日期:2026-11**
**关联分支:`main`**
**定位:`docs/VALUE_MANAGEMENT_REFACTORING.md` 的子文档,落实其 §3.5、§3.7、§5 Stage 4 与 §7 问题 3**

> **实现说明(S15)。** public 面是 `JSPersistentHandle` 协议，具体类型为
> `JSCPersistentHandle`/`QJSPersistentHandle`；identity 是 public
> `JSPersistentHandleIdentity`，registry 仍是 package
> `JSPersistentHandleRegistry<ContextHandle>`。scope/context 上的
> `makePersistentHandle` 接受非拥有值视图（`Value` /
> `CallbackValue`，都是所属 context 的类型），不再使用 `JSValue<E>` 这类泛型。下文保留少量
> 设计时的 `JSPersistentHandle<E>` 记法用于解释决策；实现以当前
> `Sources/SwiftJavaScript/Surface/JSPersistentHandle.swift` 为准。

本文档 §1–§10 为设计;§11 是 2026-11-23 的基准实测记录。本片只运行了
`swift build -c release --product PersistentHandleBenchmarks` 与基准可执行文件;
`swift test` 按编排约定未在本片运行。§1–§10 的代码引用来自设计时的最终树;
语言特性结论来自 `/tmp` 下的 `swiftc -typecheck` 探针(命令与输出见 §1.2、§2.3、§2.4,
均在仓库之外)。

---

## 0. 范围、前提与术语

### 0.1 本文档决定什么

| 章节 | 决定 |
|---|---|
| §1 | handle 的类型形态、命名、identity 表示 |
| §2 | 所有权与清理调度、显式 `invalidate` 的去留 |
| §3 | registry 的挂载点、槽位分配、generation、并发不变量 |
| §4 | 容器消亡、绑定替换/删除、弱引用强度 |
| §5 | resolve 路径与 `track`/`claim` 决策 |
| §6 | 初版绑定粒度(`ContextLocal` vs `RuntimeLocal`)与公开 API 面 |
| §7 | 与 Stage 3(默认 scope / `persist` / arena)的接面 |
| §8 | 测试与验收口径 |

不决定:异步桥接/Promise(父文档 §3.7 已预留,非目标 1)、多 isolate 并行(非目标 2)、
`JSValue`/`JSCallbackValue` 合并(Stage 5)、typed host-value 存储(见 openQuestions)。

### 0.2 三条不可协商的前提(来自现有代码)

1. **值视图是本地值,不拥有引用**——`JSValue` 协议的具体实现只有 `handle + ContextHandle`
   两个 Copyable 身份 token,`deinit` 不释放（`Sources/SwiftJavaScript/Surface/JSValue.swift`）。
2. **arena 是本地值的唯一释放账本**——`ScopeFrame.track` 按策略根化、`drain` 先 unroot
   再 `releaseCreatedHandle`,`takeFirst` 摘除时同步解除根化
   (`Sources/SwiftJavaScript/ScopeCore.swift` 的 `ScopeFrame`)。任何新增层都必须与这份账本
   对账,不能拥有"看不见的引用"。
3. **引擎调用只允许发生在 VM 的专用串行 executor 上**——`JSVirtualMachine` 协议的具体 VM
   持有 `VMThread`(`ThreadAffinityExecutor` 库 `DedicatedThreadExecutor` 的薄包装,
   `Sources/SwiftJavaScript/VMThread.swift`)。`JSCContext`/`QJSContext` 的 teardown 由
   `isolated deinit` 在该线程执行(`Sources/SwiftJavaScript/JSContextStorage.swift`);2026-11-23 起
   生命周期两端也都在该线程:runtime 与 context 的创建经 `VMThread.runAndWait` 投递并等待,
   runtime 的释放同样投递,自保活输入(`JSPreparedScript`/`JSPropertyStringKey`)的析构经
   `VMThread.perform` 投递(§3.5)。持久层不得新增任意线程的引擎访问。

Stage 4 的待办原文见 `TODO.md` §2.6;其中"弱引用不阻 GC"一条与本设计冲突,
处置见 §4.4。

### 0.3 术语

| 术语 | 含义 |
|---|---|
| **binding** | registry 槽位里的一份额外 rooted 引用,对应一个 JS 值 |
| **registry** | 容器侧(本设计:context 侧)的槽位表,持有 binding 并负责结算 |
| **identity** | `(registryID, slot, generation)`,handle 唯一的公开身份 |
| **settle** | 解除 binding 的根化并释放引用:JSC `JSValueUnprotect` + no-op release;QuickJS identity unroot + `JS_FreeValue` |
| **pump** | 在 VM 线程上执行待结算槽位的清理循环 |

---

## 1. handle 类型形态

### 1.1 命名:选 `JSPersistentHandle`

候选与结论:

| 候选 | 判断 | 理由 |
|---|---|---|
| **`JSPersistentHandle` 协议 + `JSCPersistentHandle`/`QJSPersistentHandle`** | **采用** | 与仓库命名一致(`JSCallbackValue`/`JSPreparedScript`/`JSCallbackReturn` 均为 `JS` + 描述性后缀);"handle"在本仓库已明确指身份 token(`JSValueHandle` 借用、`OwnedValueHandle` 所有权载体),而本类型正是"身份、无访问权"的极端形态;`persistent` 精确对应父文档 §3.5 的"唯一长期存储形态" |
| `JSRef` | 否决 | 与后端的 `ref`/`rawRef`(`JSCValueHandle.ref`、`QJSValueHandle.rawRef`)以及 `JSValueRef` 概念撞车;它读起来像"借用引用",而本类型的核心是"容器侧绑定 + 可失效身份" |

配套命名:`JSPersistentHandleRegistry<ContextHandle>`(package,按 context handle
参数化)、public `JSPersistentHandleIdentity`、
`JSPersistentHandleRegistryKey<ContextHandle>`(package,`JSContextDataKey` 实现)。

### 1.2 载体形态:引用计数类、真 `Sendable`、`Hashable`、**不是** `~Copyable`

```swift
public protocol JSPersistentHandle: Sendable, Hashable {
  var identity: JSPersistentHandleIdentity { get }

  /// 立即让身份失效;引擎引用在下一个串行执行回合结算。幂等。
  /// - Returns: 本次调用是否杀掉了一个仍存活的绑定。
  @discardableResult
  func invalidate() -> Bool
}

public struct JSPersistentHandleIdentity: Sendable, Hashable {
  public let registry: UInt64   // registry 创建时从进程级原子计数器取得
  public let slot: UInt32
  public let generation: UInt32
}

public final class JSCPersistentHandle: JSPersistentHandle, Sendable {
  public let identity: JSPersistentHandleIdentity
  private let registryReference: PersistentRegistryReference<JSCEngine>
  // ...
}
```

四条形态约束及其依据:

1. **必须是 class(引用计数对象)**。父文档 §3.5 要求"最后一个 owner 释放时清理",而结构体没有
   `deinit`;"handle 是引用计数对象"是 `VALUE_MANAGEMENT_REFACTORING.md` §3.5 的原文要求。
2. **不能是 `~Copyable`**。本类型的存在意义就是被宿主对象存储、被放进集合、跨隔离域传递;
   `~Copyable` 会直接否定目标场景。这与 `JSValue` 的 `~Copyable` 不矛盾:`JSValue` 是"窗口内
   借用的本地值",handle 是"跨窗口持有的身份"。
3. **必须是真 `Sendable`,而不是 `@unchecked Sendable`**。handle 唯一的可变状态是弱引用本身。
   实测(Swift 6 模式):`Sendable final class` 里的 `weak var` 会被拒绝——
   `probe12.swift:5: error: stored property 'registry' of 'Sendable'-conforming class 'H' is mutable`
   (命令:`swiftc -swift-version 6 -typecheck /tmp/persistprobe/probe12.swift`)。
   因此用标准的 `WeakBox` 包装后,handle 本身只有 `let` 存储属性,可诚实地声明 `Sendable`
   (`probe14.swift` 同命令 `TYPECHECK_OK`):
   ```swift
   final class PersistentRegistryReference<ContextHandle: JSContextRuntimeDriver>: @unchecked Sendable {
     weak var value: JSPersistentHandleRegistry<ContextHandle>?
   }
   ```
   `@unchecked` 的承诺仅限该内部箱:弱引用在 `init` 设置一次、之后只读;ARC 的弱加载/清零
   本身是线程安全的。
4. **`Hashable` 按 identity,不按对象地址**。当前每次 mint 只产生一个 handle 对象,二者等价;
   按 identity 比较为将来"同一 binding 的多个 handle"留出语义空间,也让 `invalidate` 之后
   字典键保持稳定(失效不改变 identity)。

不选 `struct + 内部 token class`:句柄的 `deinit` 必须与"最后一个 owner"严格同步;外包一层
struct 会让用户持有 struct 时 token 被复制,释放时机变成"最后一个 struct 副本",语义相同但
多一层间接,且 `Hashable` 仍要转发。没有收益。

### 1.3 identity:`(registryID, slot, generation)`

**采用**:`registryID: UInt64` + `slot: UInt32` + `generation: UInt32`(共 16 字节)。

三个字段各自回答一个失效问题:

| 字段 | 回答 | 失效来源 |
|---|---|---|
| `registryID` | "这个 handle 属于哪个容器" | 跨 context、跨 VM、容器销毁后重建 |
| `slot` | "绑定在表里的哪一格" | 槽位回收/复用 |
| `generation` | "是不是复用前的旧身份" | 槽位复用后的 ABA |

**为什么不用引擎 handle 做身份**:

- JSC:`JSCRuntimeHandle` 只有 `JSContextGroupRef` 与 `ownsRuntime`
  (`Sources/SwiftyJavaScriptCore/JavaScriptCoreRuntimeHandle.swift` 的 `JSCRuntimeHandle`),group 释放后地址可被
  下一次 `JSContextGroupCreate` 复用——用地址识别容器存在 ABA。
- QuickJS:`QJSRuntimeHandle` 恰好为此加了 `runtimeID`
  (`Sources/SwiftyQuickJS/QuickJSHandles.swift` 的 `QuickJSRuntimeIdentityRegistry`),但那正是后端私有知识;
  core 不应依赖具体引擎的 identity 方案。
- **registry 自铸 ID 是引擎无关的**:进程级原子计数器,registry 创建时取一次;进程内单调,
  永不复用。它还让"跨容器解析"退化成一次整数比较(§5.2 第 1 步)。

**generation 语义**(必须成文,否则实现会漂移):

- `0` = "从未发放";新 chunk 的槽位初值全为 0,因此零初始化的 identity 永远不命中;
- 发放时 `generation += 1`,handle 记录该值;
- 死亡(invalidate / 最后 owner)时再 `generation += 1`:这样"已死但未复用"也是可表达的,
  且下一次发放得到的新值不可能与任何仍存活的 handle 相同;
- 到达 `UInt32.max` 时**永久退役该槽位**(不再入 free list),而不是回绕。退役带来的内存损失
  是每槽 4 字节级别,ABA 带来的则是 use-after-free,取舍不成立。

**不采用"单调 token + Dictionary"**:token 永不复用意味着 32 位会耗尽、64 位会无界增长;
每次解析要哈希;槽位复用这一节本身不存在,generation 也就没必要。Stage 4 的基准测试
(`TODO.md` §2.6)用于校准槽位表的容量/分块,而不是在"是否槽位"上翻案(§3.6)。
也不采用"裸指针/不透明 box 地址":容器销毁后地址可复用,且无法区分"容器不同"与"绑定不同"。

### 1.4 存储内容与"持有不授权访问"

handle 里**没有** engine handle、**没有** `ContextHandle`、**没有** VM/context 引用:

```
JSPersistentHandle
  ├── identity: (registryID, slot, generation)     ← 纯值
  └── registryReference: WeakBox<Registry>          ← 仅用于 invalidate/deinit
```

这是父文档 §3.5 实现要点 3("handle 自身不暴露任何 JS 操作——恢复访问必须经 scope 见证")的直接
编码:**resolve 根本不经过 handle**,而是由容器 + 见证发起(§5.1)。handle 上不存在任何可以
被误用为"访问"的方法。

注意区分:registry 侧另存一份**非 retain 的** `E.ContextHandle` 用于 settle(§3.1),它是
registry 的内部依赖,不出现在 handle 上,也不增加 context 的引用计数。

对照既有类型:`JSPreparedScript`/`JSPropertyStringKey` 是 `Sendable, ~Copyable`,并在 init 里
`contextHandle.retainReference()`、在 `deinit` 里释放
(`Sources/SwiftJavaScript/JSPreparedInputs.swift` 的 `JSScopeWitness`、`JSPreparedScript`)。**持久 handle 明确不采用这个
形状**:它不保活 context(理由见 §2.6),也不在 `deinit` 里直接触碰引擎(理由见 §2.3)。

### 1.5 分叉与取舍

| 分叉 | 选择 | 被否决方案及理由 |
|---|---|---|
| 命名 | `JSPersistentHandle` | `JSRef`:与 `ref`/`rawRef`/`JSValueRef` 撞车,且暗示借用而非容器绑定 |
| 载体 | `final class` | struct:无法 `deinit`,最后 owner 释放无处挂载 |
| 可拷贝性 | `Copyable + Sendable` | `~Copyable`:否定"被存储/跨域传递"的存在意义 |
| Sendable 实现 | 真 `Sendable` + 内部 `WeakBox` | `@unchecked Sendable` 直接标在公开类型上:对用户的承诺面太大 |
| identity | registry 自铸 ID + slot + generation | 引擎 handle 地址(JSC ABA)、单调 token + Dictionary(无界增长/哈希) |
| 泛型 | `JSPersistentHandle` 协议 + context 的 `PersistentHandle` 具体类型 | 直接在 handle 上暴露 engine 静态面:registry 的 claim/root/settle 只存在于 `JSEngineValueTypes` 的 handle 层 |

---

## 2. 所有权

### 2.1 一个 handle = 一个 binding = 一份 owned 引用

- 每次 mint 分配一个槽位、取得一份**独立**的 owned 引用;同一个 JS 值 mint 两次就是两个
  binding、两份引用(去重不在 v1,见 openQuestions)。
- 复制 handle 只增加 ARC 计数,不复制 binding;最后一次 ARC 释放触发结算。
- 因此"引用计数"有两个层次:**handle 对象是 ARC 引用计数**;**binding 不是引用计数的**,
  它的生命周期完全由唯一的 handle 对象决定。这个简化成立的前提是"一个 binding 只有一个
  handle 对象",本设计保持该前提。

### 2.2 mint 取独立引用:`claim` + `root`,而不是 `persist` 的转移

mint 的引擎动作严格复用父文档 §3.7 `explicitRoots` 的结算对
(`ScopeFrame.track`/`drain`,`Sources/SwiftJavaScript/ScopeCore.swift`):

```
mint:    owned = context.claimOwnedValueHandle(borrowed)   // JSC identity / QuickJS JS_DupValue
         context.rootOwnedValueHandle(owned)              // JSC JSValueProtect / QuickJS identity
         slot.payload = owned                             // 单份所有权落在 registry 槽位

settle:  context.unrootOwnedValueHandle(payload)           // JSC JSValueUnprotect / QuickJS identity
         context.releaseCreatedHandle(payload)             // JSC no-op / QuickJS JS_FreeValue
```

| 引擎 | mint 后的计数 | settle |
|---|---|---|
| JSC | protect +1(identity claim) | unprotect,`releaseCreatedHandle` 为 no-op(`JSCContextHandle` 的同名方法,`Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreEngineRuntimeDriver.swift`) |
| QuickJS | refcount +1(`claimOwnedValueHandle`,`QJSContextHandle` 的同名方法,`Sources/SwiftyQuickJS/Engine/QuickJSEngineRuntimeDriver.swift`) | `JS_FreeValue`(root 为 identity) |

**为什么 mint 不能像 `persist` 那样转移**:`persist` 是"提升",语义是源 arena 的引用随值搬走
(`ScopeCoreHandleSurface.persistHandle`,`Sources/SwiftJavaScript/ScopeCoreHandleSurface.swift` 的 `takeFirst` + `target.track`,源无可摘除元素时
`claimOwnedValueHandle` 兜底)。它隐含一个契约:调用后源值不再被使用。mint 无法继承这个隐含
前提——调用者刚 mint 完,通常还要在同一个窗口里继续用那个值;而且一个 handle 会被多次解析
(§5.3)。所以 **mint 是复制语义,`persist` 是转移语义**,二者在文档与注释里必须并列表述
(§7.3)。

registry 额外承担一次 root 的理由:registry 活在堆里,和默认 scope 一样看不见 JSC 的隐式栈根
(父文档 §3.7)。binding 的 root 保证"即使没有任何 scope 持有它,JS 对象也不会被 GC 收走";
resolve 之后本地视图的 root 是**另一份**,由接收帧按自己的策略决定(§5.3)。

binding 不限于对象:数字/布尔/null/undefined 同样可以 mint。refcounted 引擎对立即值 dup、
GC 引擎对非对象 protect 都是既有默认 scope 已经在依赖的行为(`rootOwnedValueHandle` 对任意
`JSValueRef` 成对调用,`JSCContextHandle.rootOwnedValueHandle` / `unrootOwnedValueHandle`,`Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreEngineRuntimeDriver.swift`),本层不引入新语义。

### 2.3 最后 owner 释放:deinit → 元数据 → VM executor 泵

`JSPersistentHandle.deinit` 不能释放引擎引用:它可能在任意线程、且可能发生在
`JSContext` 已经进入 teardown 的一瞬。设计成两段:

```
任意线程(deinit / invalidate):
  registry.release(identity)                       // 只在 Mutex 内改元数据
    ├── closed || state != live || generation 不匹配 ? return   // 幂等
    ├── state = pendingRelease; generation += 1              // 身份立即死亡
    ├── pending.append(slot)
    └── if !pumpScheduled { pumpScheduled = true; scheduler.schedule { pump() } }

VM 线程(pump):
  loop:
    lock: closed ? 清 pumpScheduled 并退出
    lock: 取 pending 头;若空则 pumpScheduled = false 并退出
    lock: state == pendingRelease ? (state = settling; move payload 出槽位) : 跳过
    unlock
    settle(payload)      // unroot + releaseCreatedHandle;用 registry 持有的、非 retain 的
                         // E.ContextHandle(§3.1);引擎调用,锁外
    lock: state = free; slot 入 free list
```

`settle` 依赖 registry 保存的 `E.ContextHandle`,且该 handle **只在 `closed == false` 时被解引用**
(§3.1)。`closed` 一旦置位,泵里残留的待结算槽位由 `close()` 负责(两者同在 VM 线程,串行)。

**为什么 payload 留在槽位、清理任务只携带 identity**:清理闭包必须是 `@Sendable`,
而 `E.OwnedValueHandle` 是关联类型(`JSOwnedValueManualReferenceCountedHandle`,
`Sources/SwiftJavaScript/JSManualReferenceCountedHandle.swift` 的 `JSOwnedValueManualReferenceCountedHandle`),在泛型位置无法被
逃逸闭包消费。实测(Swift 6 模式):

- `probe9.swift:3:47: error: reference to captured parameter 'h' in concurrently-executing code`
  (泛型 `X: H & ~Copyable, Sendable`,闭包内 `consume h`);
- 具体类型可以:`probe11.swift`(`struct NC: ~Copyable, Sendable`,`@Sendable` 闭包内
  `consume nc`)`TYPECHECK_OK`。

命令均为 `swiftc -swift-version 6 -typecheck /tmp/persistprobe/<file>.swift`。
用 `@unchecked Sendable` box 包装 `~Copyable` 也能编译(`probe10.swift` `TYPECHECK_OK`),
但那会给每次释放多加一次堆分配,并把"唯一所有权点"从槽位搬到 box;本设计选择更便宜的
"槽位持有 payload、任务只携带 `(registryID, slot, generation)`"。

代价是**槽位复用被泵延迟一个执行回合**。这是有界的:引用不会泄漏到下一个回合之后,
代价只是槽位表在峰值附近多占一个位置。

调度侧的引用细节:已入队的泵闭包强持有 registry(直到执行完毕),registry 因此可能比 actor 或
箱子晚一步释放。这不延长引擎生命周期——`close()` 已把 `closed` 置位,迟到的泵只做 no-op,
不会解引用其中保存的 context handle(§3.1)。

**幂等性**:`release` 只在 `!closed && state == live && generation` 匹配时生效;`close()` 之后
一律 no-op。deinit 与 `invalidate()` 竞争、deinit 与 `close()` 竞争都落到同一判定。`close()`
自己先把 `closed` 置位、再扫描槽位(§3.5),因此"close 扫描之后才到达的 release"不可能留下
永远不会被泵的 pendingRelease。

### 2.4 调度原语:三条路线,推荐"专用线程 executor 的 closure 队列"

| 方案 | 保证 | 代价/风险 | 结论 |
|---|---|---|---|
| (a) `Task(executorPreference:)` | 需要执行器符合 `TaskExecutor` | 实测(6.4.2)`Task(executorPreference: e)` 对仅符合 `SerialExecutor` 的类型报 `probe1.swift:9:28: error: argument type 'MyExec' does not conform to expected type 'TaskExecutor'`;补上 `TaskExecutor` 后 typecheck 通过(`probe3.swift` `TYPECHECK_OK`)。**首段同步体是否必定落在该线程,需要运行时探针确认**(已由 SE-0417 原文闭合,见本节末) | 首版备选,**2026-11-23 起现用** |
| **(b) 专用 executor 增开 closure 队列** | 主循环本身就在该 OS 线程上,`semaphore` 已存在;锁内 append + `signal`,循环优先 drain | 需要改 `JSVirtualMachine.swift` 的私有 `State`(加 `cleanupJobs` + `stopped` 时丢弃) | 首版实现,**2026-11-23 起退役**(见本节末) |
| (c) 钉在 VM executor 上的 actor + `Task { await pump.drain() }` | 由 actor 语义保证落在 `unownedExecutor` 上(测试里的 FIFO 哨兵就是这个形状:`IsolatedDeinitBarrier`,`Tests/SwiftJavaScriptTests/JSEngineCoreTypesTests.swift`) | pump actor 必须**强持有 executor 对象**才能保证 `unownedExecutor` 不悬垂;多一次 actor 分配 | 备选 |

方案 (b) 的形状:

```swift
// JSVirtualMachine.swift,私有 executor 内
struct State {
  var jobs: [UnownedJob] = []
  var cleanupJobs: [@Sendable () -> Void] = []
  var stopped = false
}

// 主循环每轮在取 UnownedJob 之前先 drain cleanupJobs(同一个 Mutex、同一信号量);
// stopped 之后 append 的 cleanup 直接丢弃(不会执行,也不会泄漏引擎引用——close 已结算)。
package func schedule(_ body: @escaping @Sendable () -> Void)
```

关键性质:cleanup 与 actor job 共享**同一个 OS 线程**,因此 §3.5 的"payload 只在 VM 线程被
触碰"不变量自动成立。`stopped` 后丢弃是安全的:所有 binding 在 `close()` 时已经内联结算。

**实现演进(2026-11-23)**:Stage 4 首版按方案 (b) 落在自写的 `DedicatedThreadSerialExecutor` 上。执行器随后
整体换成 `ThreadAffinityExecutor` 库的 `DedicatedThreadExecutor`,闭包投递随之改为方案 (a) 的形态——
`Task.detached(executorPreference: executor) { body() }`。依据:

- SE-0417:"Tasks created this way are **immediately enqueued** on given executor"——任务创建即进入
  执行器唯一的那条 FIFO,与 actor job 同队列。所以 (b) 的"结算先于其后入队的 actor job"仍然成立,
  而且从"闭包优先于已排队的 job"变为严格 FIFO。
- (a) 那一格的"首段线程语义待运行时探针"由上一条原文闭合;执行器须符合 `TaskExecutor`,
  `ThreadBoundExecutor` 同时符合 `SerialExecutor` 与 `TaskExecutor`。
- 已知不遵守偏好的记录(swiftlang/swift#74395 的 `Task.yield()`/`Task.sleep()`、论坛帖 84626 内层
  任务 await 后的 continuation)都发生在挂起/恢复;这里投递的闭包体是同步的,没有挂起点。
- 用 `.detached`:不继承创建处的隔离、优先级与 task-local——从别的 actor 的 job 里触发结算时,
  不会把那个 actor 的隔离带到 VM 线程。

### 2.5 显式 `invalidate()`:保留

**保留**,语义三条:

1. **身份立即失效**:元数据在锁内切换为 `pendingRelease`、generation 递增;此后任何 resolve
   返回 `nil`。
2. **引擎引用异步结算**:在下一次串行执行回合回收。它不是"同步释放",API 注释必须写清。
3. **幂等 + 任意线程可调用**:返回本次调用是否真的杀掉了一个活绑定(`@discardableResult`)。

保留的理由:

- **提前释放**是 handle 相对"塞进默认 scope"的唯一硬收益。默认 scope 到 context deinit 才
  结算,长寿命 context 会持续累积(`TODO.md` §2.5 遗留项 ①);没有 `invalidate`,handle 只是
  多了一层间接的默认 scope。
- **确定性地断环**:JS 对象 → 宿主对象 → handle → JS 对象这类环,只有显式失效能主动断开。
- 基准测试需要一个可重复的"释放"动作(`TODO.md` §2.6)。

否决"只保留自动清理":那样"最后 owner 释放"与"显式释放"两条路径中只剩一条,而唯一 owner
可能是一个长寿命宿主对象——句柄的引用生命周期会比 JS 值的实际用途长得多。

### 2.6 不保活容器(与 `JSPreparedScript` 的刻意差异)

handle 不 retain context/VM(§1.4)。反面论证:若 handle retain context,则

```
context ──► registry ──► binding ──► JS 对象 ──► 宿主对象 ──► handle ──► context
```

一个宿主对象里存一个 handle,就把 context 永久保活;而"容器消亡 → resolve 得 nil"这条
父文档 §3.5 的核心承诺永远不会发生(容器不会死)。因此 handle 必须弱引用 registry,registry 只由
容器持有。

区分两个"持有":

- **handle → registry 是弱引用**(本节的结论);
- **registry → `E.ContextHandle` 是非 retain 的值拷贝**(§3.1),不增加引用计数,因而不构成保活;
  context 的最后一次释放仍由 `JSContext.isolated deinit` 的 `releaseReference()` 完成。

与同族风险的关系:`JSPreparedScript` 的 `deinit` 在任意线程调用 `releaseReference()`
(`JSPreparedScript.deinit`,`Sources/SwiftJavaScript/JSPreparedInputs.swift`),这已被登记为同族线程风险(`TODO.md` §2.5 ⑤)。持久层不复制
这个形状:**任意线程只做元数据操作,引擎调用只在 VM 线程发生**(§2.3、§3.5)。

### 2.7 分叉与取舍

| 分叉 | 选择 | 被否决方案及理由 |
|---|---|---|
| mint 的引用 | `claim`(复制)+ root | `persist` 式转移:源值在 mint 后仍需可用;一个 handle 多次解析 |
| 释放语义 | 自动清理 + 显式 `invalidate` | 仅自动清理:长寿命 owner 使提前释放不可能;仅显式:忘记调用即泄漏到容器死亡 |
| 清理调度 | executor 的 closure 队列(方案 b) | `Task(executorPreference:)`:首段线程语义待运行时验证;sentinel actor:多一次分配 + 需强持有 executor |
| 清理负载 | 槽位持有 payload,任务携带 identity | 让闭包携带 `E.OwnedValueHandle`:泛型 `~Copyable` 无法被 `@Sendable` 逃逸闭包消费(实测);box 方案:每次释放一次堆分配 |
| 容器保活 | 不保活(弱引用) | 保活:构造出不可回收的环,"容器消亡得空"永不触发 |

---

## 3. registry 组织

### 3.1 挂载点与生命周期:actor 持有 + 箱子发布

**采用**:每个 `JSContext` 一个 registry,由**两方共同参与**:

- **权威生命周期**:`JSContext` 以一个存储属性持有它(`persistentRegistry`,两个 init 都创建);
- **访问路径**:箱子存在时,把**同一个对象**发布进 `JSContextDataStorageBox`
  (`Sources/SwiftJavaScript/JSContextData.swift` 的 `JSContextDataStorageBox`),由一个内部 `JSContextDataKey` 寻址,
  供 `JSInstantContext`/`JSScope` 在同步路径上取用。

两条缺一不可:

1. **访问路径必须在箱子里**。回调拿到的是 `borrowing JSInstantContext`,不是 actor;只有经
   `driverContextHandle.contextDataStorageBox()` 才能在同步路径上取到 registry
   (`JSInstantContext.setData` / `data(for:)` 已用同一入口做 context data)。只放 actor 存储属性会强制
   每次 mint 穿一次 actor 隔离——回调里根本做不到。
2. **生命周期不能交给箱子**。`installContextDataStorageBox(_:)` 是公开的 driver requirement
   (`JSContextRuntimeDriver.installContextDataStorageBox(_:)`,`Sources/SwiftJavaScript/Engine/JSEngineRuntimeDriverProtocol.swift`),任何拿到 `ContextHandle` 的代码都能在**任意线程**
   清空/替换箱子;箱子又会在 `releaseReference()` 之前被清空(`JSContext` 的 `isolated deinit`)。
   若 registry 只由箱子持有,一次外部清箱就会销毁一个仍有活绑定的 registry——引擎引用永久泄漏,
   且随后到来的泵可能用已释放的 context 结算。由 actor 持有后,外部清箱只降级为"scope 见证侧
   失去访问路径":registry 存活到 `isolated deinit`,在那里统一 `close()`;handle 的弱引用仍有效,
   `invalidate()` 仍可结算,actor 侧的 mint/resolve 仍可用。

此外,**不需要新 driver requirement**。
`contextDataStorageBox()`/`installContextDataStorageBox(_:)` 已是 `JSContextRuntimeDriver` 的
硬 requirement(`JSContextRuntimeDriver.contextDataStorageBox()` / `installContextDataStorageBox(_:)`),持久层的引擎面完全由既有的
`claimOwnedValueHandle`/`rootOwnedValueHandle`/`unrootOwnedValueHandle`/`releaseCreatedHandle`
组成——**Stage 4 的 core 实现不需要任何后端改动**。(2026-11-23 起两个后端的
`installContextDataStorageBox` 方法体改为经 core 的 `swapContextDataStorageBox` 路由,不新增
requirement,见 §3.7 与 §3.5。)

非选方案:

| 方案 | 否决理由 |
|---|---|
| 仅 `JSContext` 存储属性 | 回调/`JSScope` 不可达(actor 隔离);每次 mint 一次 hop |
| 仅箱子持有 | 公开的清箱入口可在任意线程销毁仍存活的 registry(见上) |
| 进程级静态表(仿 `ScopeStackRegistry`,`Sources/SwiftJavaScript/ScopeCore.swift`) | 生命周期不随容器;容器未走正常路径时条目泄漏;已在 Stage 1 为此付出过 pop 纪律成本。这条否决只针对**持有 registry**;不持有任何东西的 VM 线程绑定后来直接挂在既有 scope 栈条目上,没有新增表(§3.5) |
| VM 级注册表 | 见 §6(结算需要活 context;JSC root 是 context 寻址) |

创建时机:`package init` 内创建(此时 `virtualMachine` 可用,用于取调度句柄);公开 `init` 在
箱子安装之后把同一对象发布进箱子。registry 的组成:

```
id: UInt64                                   // 进程级原子计数
driverContextHandle: E.ContextHandle         // 值拷贝,不 retain(见下)
scheduler: any JSPersistentCleanupScheduler  // 保留 executor 对象,不保留 runtime/context 引用
state: Mutex<…>                              // closed / pumpScheduled / chunks / freeList / pending
```

不分配槽位,直到第一次 mint。裸 context 分两种:

- 经 `JSContext` 的 `package init`(无箱子,常见于 Mock):registry 存在,**actor 侧**的
  `makePersistentHandle`/`resolve` 可用;scope 见证侧不可达(mint `preconditionFailure`,
  resolve 返回 `nil`);
- 直接构造的 `JSInstantContext(handle:)`(无 hosted `JSContext`):没有 registry。

两者与"裸 context 没有默认 scope"(父文档 §3.6)是同级别的边界。

**`E.ContextHandle` 的持有规定:值拷贝、不 retain。**

- 必要性:`unrootOwnedValueHandle`/`releaseCreatedHandle`/`claimOwnedValueHandle`/
  `rootOwnedValueHandle` 是 `E.ContextHandle` 的实例方法
  (`JSContextRuntimeDriver` 的 release/claim/root/unroot 要求),没有它就无法 settle。
- 不 retain 与 scope 层同形:`ScopeFrame.driverContextHandle` 就是非 retain 的值拷贝
  (`ScopeFrame.driverContextHandle`)。context 的最后一个引用仍由
  `JSContext.isolated deinit` 的 `releaseReference()` 释放——QuickJS `JS_FreeContext`
  (`QJSContextHandle.retainReference` / `releaseReference`)、JSC `JSGlobalContextRelease`
  (`JSCContextHandle.releaseReference`),且发生在 VM 线程。
- 代价是一条必须成文的规则:**`close()` 之后 registry 不得再解引用该 handle**。所有引擎入口
  先检查 `closed`(锁内);`close()` 在 `releaseReference()` 之前执行,所以不存在"用已释放
  context 结算"的窗口。
- **否决 retain**:那会把引擎 context 的最终释放挪到 registry 的释放点(泵闭包执行完、箱子
  被外部清空、或 actor 存储销毁),既不能保证 VM 线程,也不再满足 §4.1 的
  "`releaseReference()` 必须是最后一步"。

不变量:箱子里的条目**只安装一次**;外部清箱不会销毁 registry,只移除访问路径(不做自动重建,
见 openQuestions)。

### 3.2 单级还是两级:单级(理由与 §6 合并)

v1 只有 context 级注册表。identity 的 `registryID` 与 registry 的内部实现都保持"粒度中立"
(registry 不知道自己是 context 还是 runtime 的),这样将来加 `RuntimeLocal` 只是新增一个
mint/resolve 入口,而不是换 handle 类型或改 identity 布局。详见 §6.3。

### 3.3 查找:O(1)

```
resolve(identity):
  guard identity.registry == registry.id else { nil }        // 容器错/已销毁/重建
  guard slot < chunkCount * chunkCapacity else { nil }
  lock: state == live && generations[slot] == identity.generation ? 复制出 borrow token : nil
```

一次整数比较 + 一次数组索引 + 一次锁内读。没有哈希、没有链式碰撞。

### 3.4 槽位分配、回收与存储形态

分块 slab,与 `ScopeArenaChunk` 同样的理由:`Array` 不能持有 `~Copyable` 元素
(`ScopeArenaChunk`,`Sources/SwiftJavaScript/ScopeCore.swift`),而槽位必须原样存放 `E.OwnedValueHandle`。

```
chunk(capacity 32, 与 scopeArenaChunkCapacity 对齐):
  payloads: UnsafeMutablePointer<E.OwnedValueHandle>   // 未初始化槽位不构造
  generations: [UInt32]                                // 0 = 未发放
  states: [UInt8]                                      // free / live / pendingRelease / settling
  next: Chunk?
registry:
  chunks: [Chunk]
  freeList: [UInt32]                                   // 已结算且 generation 未耗尽的槽位
```

状态机(四个状态,`settling` 不可省):

```
free ──allocate(generation+1)──► live
live ──invalidate/deinit(generation+1)──► pendingRelease          (仅元数据)
live/pendingRelease ──pump 或 close:锁内 move payload 出槽位──► settling
settling ──锁外 settle 完成,锁内登记──► free(入 freeList)
任意 ──close:closed = true 后逐槽走上面两条路径──► closed(registry 级)
```

- **`settling` 表示"payload 已移出、引擎结算进行中或已完成"**。它把"内存已未初始化但状态仍
  写着 pendingRelease"这个窗口显式化:`close()`、迟到的 pump、以及引擎 finalizer 重入触发的
  `release` 看到非 `live` 状态都只 no-op,不可能二次 move(§3.5)。
- **分配**:free list 非空则 pop;否则在 head chunk 有空位时用下一个索引;否则新开 chunk。
  32 位槽号上限 = 4G 并发绑定,对本层不构成现实约束;耗尽时 `preconditionFailure`(与既有
  工厂失败路径一致)。
- **回收**:只有 pump(或 close)能把槽位放回 free list(§2.3 的代价,有界)。
- **chunk 裁剪**:v1 不裁剪。chunk 数量由**峰值并发 handle 数**决定,不是累计 mint 次数;
  若基准显示峰值驱动的常驻内存重要,再引入"尾部空 chunk 释放"(openQuestions)。
- 订阅式释放账本不需要:槽位状态就是唯一事实来源(与 `ScopeArena` 删除 `removed` 集合同理,
  `Sources/SwiftJavaScript/ScopeCore.swift`)。

### 3.5 并发不变量:元数据锁 + payload 只在 VM 线程

单一 `Mutex` 保护元数据(closed/pumpScheduled/chunks/freeList/pending);**payload 只能在
VM 线程被初始化、借用、移出**。

调用者分类:

| 操作 | 允许的线程 | 触碰 |
|---|---|---|
| `mint` / `resolve` / `close` | 仅 VM 线程(witness/actor 保证,不新增运行时检查) | 元数据 + payload + 引擎 |
| `release`(`invalidate`/`deinit`) | 任意线程 | 仅元数据 |
| `pump` | VM 线程 | 元数据 + payload + 引擎 |

竞态论证(必须写进实现注释):`release` 从不移动 payload;唯一移动 payload 的是 pump(或
close),而它们与 resolve 共享同一 OS 线程。因此"resolve 在锁内看到 live、锁外借用 payload"
期间,payload 不可能被移走或释放;`release` 期间的并发只影响元数据,而 resolve 的判定发生在
锁内。这也是为什么 `close()` 可以内联结算——它本来就在 VM 线程。

**`close()` 的顺序与锁纪律**(与 pump 同规,必须成文):

1. 锁内 `closed = true`——**先置位、再扫描**。否则 close 扫描完某槽后到达的 `release` 仍看到
   live,会把槽改成 pendingRelease 并入队,而此后已无泵执行 → 漏结算(JSC protect / QuickJS
   引用);
2. 锁内逐个把待结算槽位切到 `settling` 并 **move payload 出槽位**(纯内存操作);
3. 锁外执行 `unrootOwnedValueHandle` + `releaseCreatedHandle`;
4. 锁内登记 `free`(closed registry 不再分配,这一步只是保持状态机自洽)。

**引擎调用一律不在锁内**,close 与 pump 同此规定。原因不只是锁粒度:QuickJS 的
`releaseCreatedHandle` 就是 `JS_FreeValue`,它会**同步执行用户 finalizer**
(`Sources/SwiftyQuickJS/Engine/QuickJSEngineClassDriver.swift`:finalizer 内调用
`definition.finalize(thisValue)`),而 finalizer 里丢掉一个 handle 就会重入 `registry.release`。
`Synchronization.Mutex` 是非递归锁(本仓库的 scope 栈与 context data 都在用,
`ScopeStackStorage.state`、`JSContextDataStorageBox.state`),锁内结算会直接死锁。
`closed` 先置位保证这类重入立即 no-op;即便未 close,重入者看到的也是 `settling` 而非 `live`。

`mint`/`resolve` 的线程前置条件不做运行时断言:与 Stage 1-3 的既有契约一致(scope 见证 =
同步窗口),新增断言只会把已有的纪律重复一遍;Mock 层可以用测试显式验证。

**公共面的保证(2026-11-23)**:上表"witness/actor 保证"在公共面上成立,是因为作用域见证只能从 context
派生——`JSInstantContext.init(handle:)` 与 `JSScope.init(handle:)` / `open()` 都是 `package`,`JSScope`
的公共构造面只有 actor 隔离工厂 `JSContext.makeScope()`,而 `JSScope` 既非 `Copyable` 也非 `Sendable`,
结果跨不出 actor 边界(编译期拒绝;诊断原文记录在
`Tests/SwiftJavaScriptEngineTests/EngineScopeContractTests.swift` 的负面样例注释块)。

**VM 线程的判据与清箱路由(2026-11-23)**:执行器实现 `ThreadBoundExecutor.isIsolatingCurrentContext()`
(线程标识)。它是 `SerialExecutor` 上由执行器自己实现的钩子,协议默认实现返回 `nil` = "未知",
所以必须由执行器提供。`JSContext.init` 末尾经 `ScopeStackRegistry.bind` 把 context 绑到所属
`VMThread`,绑定随 scope 栈的最后一次 `pop` 消失——`isolated deinit` 把 pop 放在最后一步,
清箱与 context 释放期间绑定仍在(§4.1)。`VMThread` 在这判据上给两个入口:`perform`(已是
VM 线程则内联,否则投递,不等待)与 `runAndWait`(内联,或投递并等待)。路由规则:

- `installContextDataStorageBox`:经 `perform`——调用线程零引擎调用,交换先于其后入队的任何
  job,也即调用返回时尚未生效;
- runtime 与 context 的创建(`JSVirtualMachine.init`、`JSContext.init`):经 `runAndWait`——
  `init` 是同步的,返回的 actor 必须已握着 handle,调用方若在别的线程就等待创建完成。VM 线程
  从不等调用方,所以这个等待不会自己死锁;宿主不得在回调里阻塞一个正要建 context 的线程;
- `JSVirtualMachine.deinit` 的 runtime 释放:经 `runAndWait`;
- 自保活输入的析构:经 `perform`。它们 retain 引擎 context、可比 `JSContext` actor 活得久,
  scope 栈上的绑定到那时已不在,所以在创建时经 `ScopeStackRegistry.vmThread(for:)` 记下
  `VMThread`。

### 3.6 分叉与取舍

| 分叉 | 选择 | 被否决方案及理由 |
|---|---|---|
| 表结构 | 分块 slab + free list | `Dictionary`:无界增长、无槽位复用、`~Copyable` 载荷需逐条 box;§11 实测其元数据 lookup 反而快 2–5 ns,但 insert/release 慢 7–24 ns,端到端差 ≤3%——选型依据是内存有界与所有权,不是 lookup 速度 |
| 槽号宽度 | `UInt32` | `UInt64`:内存翻倍换一个不现实的容量 |
| generation | 死亡与发放各 +1,耗尽即退役 | 只按发放 +1:"已死但未复用"与"槽位空闲"不可区分;回绕:ABA |
| 并发 | 一把 `Mutex` 管元数据,payload 单线程 | 无锁 CAS 表:引擎调用无法在无锁区安全完成,复杂度不匹配 |
| chunk 大小 | 32(与 arena 对齐) | 32/64/128 由基准校准;§11 实测 32 维持,64/128 仅把 mint 降低 ~3–8 ns/op |
| 裁剪 | v1 不裁剪 | 尾部空 chunk 释放:等基准证明峰值内存重要(openQuestions) |

§11 的实测修正:boxed Dictionary 的 lookup 更快(15.7 vs 18.4 ns),但 insert/release 更贵
(61.2 vs 54.3、64.1 vs 42.3 ns),churn 基本持平;这些差距在真实 resolve(~250–650 ns)与
release(~850 ns)里 ≤3%。**槽位仍然正确,但理由应从"lookup 更快"改为"内存按峰值并发有界 +
`~Copyable` 载荷无需逐条 box + generation 在表内 + 无哈希/重哈希尾延迟"**。详见 §11.5。

### 3.7 实现落点

Stage 4 首版零后端改动;2026-11-23 起两个后端的 `installContextDataStorageBox` 方法体改为经
core 的 `swapContextDataStorageBox` 路由(§3.5),不新增 driver requirement。

| 文件 | 改动 |
|---|---|
| 新增 `Sources/SwiftJavaScript/Surface/JSPersistentHandle.swift` | `JSPersistentHandle` 协议 + public identity + `invalidate`;具体类型 `JSCPersistentHandle`/`QJSPersistentHandle` |
| 新增 `Sources/SwiftJavaScript/JSPersistentHandleRegistry.swift` | registry(含非 retain 的 `E.ContextHandle`)、槽位表、pump、`close`、内部 `JSContextDataKey` |
| `Sources/SwiftJavaScript/Surface/JSScope.swift`、`JSInstantContext.swift` | Stage 4 首版无改动(`scopeFrame` 已存在)。2026-11-23 起:`JSScope` 构造面收敛(`~Sendable`,`init(handle:)` / `open()` 降 `package`);`JSInstantContext.swift` 增加 `ScopeStack.bind` 与 `ScopeStackRegistry.bind` / `vmThread(for:)`(§3.5) |
| `Sources/SwiftJavaScript/JSPreparedInputs.swift` | `JSScopeWitness` 增加 `var scopeFrame: ScopeFrame<E> { get }` 要求,供 resolve 定位接收 frame(两个 conformer 已具备同签名成员) |
| `Sources/SwiftJavaScript/JSContextStorage.swift` | 增加 `let persistentRegistry`(两个 init 都创建);公开 init 在装箱后发布到箱子;`isolated deinit` 首行 `registry.close()`。2026-11-23 起:init 末尾绑定 VM 线程,新增公共工厂 `makeScope()` |
| `Sources/SwiftJavaScript/JSContextData.swift` | 2026-11-23 新增 `JSEngineRuntimeDriver.swapContextDataStorageBox(_:on:raw:)`(清箱的 VM 线程路由) |
| `Sources/SwiftJavaScript/VMThread.swift` | 首版:私有 executor 增加 cleanup closure 队列。2026-11-23 起:自写 executor 删除,改为 `VMThread`(包装 `ThreadAffinityExecutor` 库的 `DedicatedThreadExecutor`),闭包投递为 `Task.detached(executorPreference:)`(§2.4 末) |
| `Package.swift` | 2026-11-23 新增依赖 `swift-thread-affinity-executor`(0.1.2),`SwiftJavaScript` target 依赖其 `ThreadAffinityExecutor` 产品 |

后端(`SwiftyJavaScriptCore`/`SwiftyQuickJS`)不需要新 requirement:所需的
`claimOwnedValueHandle`/`rootOwnedValueHandle`/`unrootOwnedValueHandle`/`releaseCreatedHandle`
与 context 数据箱访问都已是 `JSContextRuntimeDriver` 的既有硬 requirement
(`Sources/SwiftJavaScript/Engine/JSEngineRuntimeDriverProtocol.swift` 的 `JSContextRuntimeDriver`)。

---

## 4. 失效路径

### 4.1 容器消亡:`isolated deinit` 内的顺序

顺序是 drain → 清箱 → release → pop(`JSContext` 的 `isolated deinit`;2026-11-23 把 pop 从清箱之前
挪到最后一步,让 VM 线程绑定覆盖清箱与释放)。新增一步,位置在 **`releaseReference()` 之前**:

```swift
isolated deinit {
  persistentRegistry.close()                    // 新增:结算 live + pendingRelease(settling 已移出,跳过)
  defaultScope.drain()                          // 既有
  driverContextHandle.installContextDataStorageBox(nil)   // 仅移除访问路径(registry 仍由 self 持有);路由判据为真,内联
  _ = driverContextHandle.releaseReference()    // 引擎 context 释放,必须最后
  ScopeStackRegistry<E>.pop(for: driverContextHandle)    // 最后:随最后一帧撤掉 VM 线程绑定
}
```

- **为什么在 `releaseReference()` 之前**:settle 需要活的引擎 context(`JS_FreeValue` /
  `JSValueUnprotect`)。这与 `defaultScope.drain()` 必须在此之前是同一个理由。
- **为什么与 `defaultScope.drain()` 的先后无关**:两份账本互不引用(§7.4);registry 的
  binding 不经过 arena。选 close 在前,是因为它更贵、且希望它在 `box` 清空之前完成。
- **`close()` 的内容**(已在 VM 线程,内联结算,不再调度):先锁内置 `closed = true`,再对
  所有 `live`/`pendingRelease` 槽位按 §3.5 的四步执行 settle(锁内 move、锁外结算)、
  generation 递增、清空 free list。
- **没有 deinit 兜底,这是刻意删除的**:registry 的 `deinit` 不结算、不触碰引擎。理由有三:
  (a) 泵闭包强持有 registry(§2.3),其生命周期不必与箱子同时结束;
  (b) `installContextDataStorageBox(_:)` 是公开的 driver 要求
  (`JSContextRuntimeDriver`,`Sources/SwiftJavaScript/Engine/JSEngineRuntimeDriverProtocol.swift`),
  调用可来自任意线程,所以箱子里的那份引用可以在任意线程被释放,registry 的兜底 close 会跟着
  最后一个释放者所在的线程执行引擎调用。(2026-11-23 起清箱本身的引擎操作已被路由到
  VM 线程,§3.5;但 registry deinit 的线程仍没有保证,这一条照旧成立);
  (c) actor 存储的销毁发生在 `isolated deinit` 体之后,此时 `releaseReference()` 已执行,
  registry 里保存的 context handle 已悬垂。三者任一都足以否决兜底。
  未 `close()` 的 registry 是编程错误:`deinit` 内 `assert(closed)`;release 构建下只释放
  Swift 侧存储,引擎引用泄漏但不崩溃、不 double free。正常路径只有 `isolated deinit` 一条。
- **registry 的最终释放**:箱子清空只释放它持有的那份引用;registry 由 `JSContext` 的存储属性
  持有到 deinit 体之后,迟到的泵闭包可能再延长一步。两条路径都发生在 `close()` 之后且不解引用
  context handle,所以顺序无关紧要。
- **handle 仍存活**:handle 对 registry 是弱引用;registry 最终释放后 `invalidate()` 静默
  no-op;resolve 经任何容器都不可能成功(容器已不存在,或新容器的 `registryID` 不同)。
  **不悬垂、不崩溃**。

### 4.2 VM 消亡:不引入任何 runtime 级结算

`JSContext` 强持有 `JSVirtualMachine`(`JSContext` 的 `virtualMachine` 存储属性),因此 VM 的 deinit 必然晚于每个
context 的 `isolated deinit`。settle 全部发生在各自 context 的收尾里;`JSVirtualMachine.deinit`
只做 `releaseReference()`——2026-11-23 起该调用经 `VMThread.runAndWait` 在 VM 线程执行(§3.5),
此前登记的"`JSVirtualMachine.deinit` 线程归属"风险随之关闭。
**持久层不得在 runtime 层新增任何引擎访问**。

### 4.3 绑定替换 / 删除

- **删除** = `invalidate()`。这是唯一的删除路径(自动清理只是"最后一个 owner 触发同一路径")。
- **替换(rebind)v1 不提供**。替换 = `invalidate` 旧 handle + mint 新 handle;宿主侧需要
  "可替换"时,把 handle 放在自己的可变字段里整体换掉(ARC 负责旧 handle 的结算)。
- 否决 in-place rebind(保持同一 identity、只换 payload,V8 `Persistent::Reset` 的形状):
  - handle 的 `Hashable`/`Equatable` 是 identity,而 in-place 替换会让"同一个键"解析出不同值,
    值语义层面构成另一种 ABA;
  - 替换必须发生在 VM 线程(引擎调用),但 handle 是 `Sendable` 的任意线程持有物,
    用户很容易在没有容器的情况下以为可以替换;
  - 当前登记的目标场景(宿主构造函数缓存、每 context 的 JS 包装、长期 JS 回调、宿主 API 注册表,
    `VALUE_MANAGEMENT_REFACTORING.md` §3.5)都可以用"换引用"表达。
  复活条件写入 openQuestions:出现"身份必须跨替换稳定"的真实用例(例如 JS 对象在重载后仍需
  被同一宿主表项索引)。

### 4.4 弱引用强度:v1 不发货,并说明为什么这是结论而不是拖延

父文档 §3.5 把 `strength: .weak` 列为强度选项,Stage 4 的验收里也写着"弱引用不阻 GC"
(`TODO.md` §2.6)。**本设计认为该条在现有引擎能力下不可实现,必须显式重写验收口径**,理由:

1. **JSC 的 C API 没有宿主侧弱引用**。`JSValueProtect`/`JSValueUnprotect` 是仅有的根化手段;
   弱引用只在 Objective-C 绑定的 `JSManagedValue` 层存在,它依赖那一层自己的 VM/GC 集成,
   C 侧无法复用。任意 JS 对象也没有可供宿主安装的 finalizer(finalize 只在
   `JSClassDefinition` 上,且只覆盖我们自建类的实例)。
2. **QuickJS 只暴露 JS 级的 WeakRef**。vendor 头里有 `JS_AddIntrinsicWeakRef` 与
   `JS_IsWeakRef`(`.build/checkouts/Swift-CQuickJS/Vendor/quickjs/quickjs.h:559,934`),
   没有宿主侧"构造弱引用/取目标"的 API。
3. 因此"不根化、但仍可安全解析"需要一个可靠的存活判定,而两个引擎都不提供。三个看似可行的
   替代都不成立:
   - 存裸 identity 判活:对象被回收后读取即 UB;
   - "不根化、靠别人保活":无法判定,resolve 无法区分"仍被 JS 持有"与"已死";
   - 读引用计数探测:引擎不暴露,且"计数 > 0"≠"未被标记回收"。

**v1 的明确语义**:handle 是**强**引用——binding 存活期间 JS 对象不会被回收;
`VALUE_MANAGEMENT_REFACTORING.md` §3.5 所说"handle 生命周期结束与 JS 对象被 GC 回收是两个独立
事件"在 v1 只有一个事件(binding 结束)。这句必须写进公开文档,避免用户按 V8/WeakRef 的心智
使用。

**可实现的弱语义子集**(登记,不在 v1):
- **finalizer 驱动的失效**:仅限库自己经 `JSClass` 包装的对象——在两个后端都可在 class
  finalize 回调里通知 registry 杀死槽位。范围窄(任意 `evaluateScript` 产物不适用),但语义可靠。
- **JS 级 `WeakRef` 互操作**:binding 存一个 JS 级 WeakRef 对象,resolve 时在引擎里调用一次
  `deref`。它要求 resolve 一定在 VM 线程(已有),代价是每次解析一次 JS 调用;对 QuickJS 可行,
  JSC 需确认其 `WeakRef` 内建可用性与 GC 时机。
两者都进入 openQuestions,并作为"弱引用验收条"重写的基础。

### 4.5 分叉与取舍

| 分叉 | 选择 | 被否决方案及理由 |
|---|---|---|
| 容器消亡通知 | `isolated deinit` 显式 `close()`,无 deinit 兜底 | 箱子释放隐式完成:箱子可被任意线程清空、可早于引擎释放,且 registry 生命周期可长于箱子(§4.1) |
| 替换 | invalidate + 重新 mint | in-place rebind:值语义 ABA、线程归属易错(§4.3) |
| 弱引用 | v1 不提供,重写验收条 | 发货一个"不阻 GC 但可能悬垂"的强度:两个引擎都无法安全判定存活 |
| 删除 | `invalidate()` | 只有自动清理:§2.5 已否决 |

---

## 5. resolve 路径

### 5.1 入口:三处,全部由见证发起

```swift
// actor;产物锚默认 scope
public protocol JSContext: Actor, Hashable {
  func resolve(_ handle: PersistentHandle) -> Value?
}

// 同步窗口;产物锚该 scope 的 arena
public protocol JSInstantContext: JSValueScope, ~Copyable {
  @available(*, noasync)
  func resolve(_ handle: PersistentHandle) -> Value?
}

// 手动 scope;产物锚该 scope 的 arena
public protocol JSScope: JSValueScope, ~Copyable {
  @available(*, noasync)
  func resolve(_ handle: PersistentHandle) -> Value?
}
```

不在 `JSPersistentHandle` 上提供 `resolve()`:那会把"持有"变成"访问权",与父文档 §3.5 的实现要点 3
冲突,也使得调用方可以绕开线程/隔离约束。

### 5.2 算法

```
resolve(handle, in witness):
  1. registry = witness.driverContextHandle.contextDataStorageBox()?.persistentRegistry
     guard let registry, registry.id == handle.identity.registry else { return nil }
  2. guard let borrowed = registry.borrowLive(handle.identity) else { return nil }
       // 锁内:slot 在界、state == live、generation 匹配;复制出 Copyable borrow token
  3. witness.scopeFrame.track(
        witness.driverContextHandle.claimOwnedValueHandle(borrowed))
       // 为接收帧申领一份新的 owned 引用(复制语义)
  4. return Engine.makeValue(handle: borrowed, contextHandle: witness.driverContextHandle)
```

`borrowLive` 只返回 Copyable 的 `E.ValueHandle`(不搬 payload),因此锁内没有引擎调用;
payload 的存活由 §3.5 的线程不变量保证。`JSContext` 入口是同一算法,只把
`witness.scopeFrame` 换成 `defaultScope.frame`(§7.2 说明其累积代价与批量写法)。

### 5.3 `track` / `claim` 决策:一律 claim 进接收帧,不转移

| 步骤 | 动作 | 依据 |
|---|---|---|
| registry → 本地视图 | `claimOwnedValueHandle`(JSC identity;QuickJS `JS_DupValue`) | 一个 handle 可被解析任意多次;转移会让它单次可用 |
| 新引用落账 | 接收帧 `track` | 本地视图不拥有引用(父文档 §3.2),不落账就是 QuickJS 漏 free / JSC 无根 |
| 根化 | 由接收帧的 `Rooting` 策略决定 | 同步帧 `implicitStackRoots` 不 root,默认 scope `explicitRoots` root(父文档 §3.7) |

要点:**binding 的 root 与本地视图的 root 是两份,互不替代**。

- binding root 保证"没有 scope 持有时 JS 对象仍活着"——这是 handle 存在的前提;
- 本地视图的 root 保证"视图有效期内引擎不会回收它"——JSC 同步帧不做(靠栈扫描 + 同线程
  保证),默认 scope 做 protect;
- 在"JSC 同步帧 + registry binding"的组合下,安全性的论证是:binding 的 protect 一直存在,
  而唯一能解除它的是 pump,又与 resolve 同线程(§3.5)。

否决"借用不记账"(让帧不持有新引用,直接返回 registry 的借用):QuickJS 上视图的生命周期将
不再由 arena 表达,而 `JSValue` 明确无所有权;这会打破"arena 是唯一释放账本"的前提(§0.2)。
否决"transfer":单次可用,且与 `persist` 的语义重复。

### 5.4 失败语义与跨容器

`nil` 的四种来源,全部不可区分(这是有意的——"为什么没了"对调用方不应成为控制流):

1. 见证路径上没有 registry(直接构造的 `JSInstantContext(handle:)`,或箱子被外部清空);
2. `registryID` 不匹配(跨 context、跨 VM、容器重建);
3. 槽号越界(表已缩小/退役);
4. generation 不匹配或 state ≠ live(已 invalidate、已 close、已被自动清理)。

**跨 context 在 v1 一律 nil**,即使 JSC 同一 context group 内值本身可用
(`JSCEngine.isContextCompatibleWith`,`Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreEngineRuntimeDriver.swift`)。
理由:binding 的 root 是用某一个 context 取的,unroot 必须回到兼容的 context;
`ContextLocal` 的语义就是"谁创建、谁解析"(§6)。

### 5.5 分叉与取舍

| 分叉 | 选择 | 被否决方案及理由 |
|---|---|---|
| 发起者 | 见证(context/scope) | handle 自身:把持有变成访问,绕开隔离 |
| 引用 | claim 复制 | transfer:单次可用;借用不记账:破坏 arena 账本 |
| 锚点(actor) | 默认 scope | 临时帧:不存在 ambient 帧;新建帧:返回值必悬垂 |
| 返回值 | `JSValue?` | `JSCallbackValue?`:构造面受限且契约含 `noasync` 窗口,而 resolve 可能发生在非回调 scope |
| 失败 | `nil` | `throws`:失败是常态(容器死亡),不是异常 |

---

## 6. 绑定粒度:初版公开面

### 6.1 结论:`ContextLocal`

v1 只发布 **context 级**绑定:`JSPersistentHandle` 由某个 `JSContext`(或其 scope 见证)
mint,并只能经同一 context 的见证解析。公开面不出现 `RuntimeLocal`/`ContextLocal` 这样的
前沿类型参数,也不出现"绑定作用域"选项。

### 6.2 四条理由(回答父文档 §7 问题 3,原问题见 `VALUE_MANAGEMENT_REFACTORING.md` §7 问题 3)

1. **QuickJS 的结算需要活的 context**。`JS_FreeValue(ctx, v)` 必须在一个 context 上执行;
   而 runtime 级绑定的结算点只能是 runtime 消亡,那时 `JSVirtualMachine.deinit` 在任意线程
   非 isolated 执行(`Sources/SwiftJavaScript/VMThread.swift` 的 `deinit`,`TODO.md` §2.5 ⑤),没有可用的 context。
   要修就得在 VM 里养一个"锚 context",那会引入第二个 realm,并使
   `JSContextGetGroup`/`JS_GetRuntime` 兼容判断多出一个隐形参与者。
2. **JSC 的 root 是 context 寻址的**。`rootOwnedValueHandle` 用 `JSValueProtect(ref)`、
   `unroot` 用 `JSValueUnprotect(ref)`(`JSCContextHandle.rootOwnedValueHandle` / `unrootOwnedValueHandle`,`Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreEngineRuntimeDriver.swift`),
   `ref` 是 `JSGlobalContextRef`。runtime 级绑定必须记录"哪个 context 取的根",并保证在该
   context 死亡前解除——这已经把两端都拖进了 per-context 记账,并没有简化。
3. **realm 语义**。全局对象/构造函数是 context 级差异(`VALUE_MANAGEMENT_REFACTORING.md` §2.4);
   runtime 级句柄经另一个 context 解析会得到另一个 realm 的值。JSC 在 group 内允许这种使用,
   QuickJS 只要求同 runtime,但两者都不是"同一个东西",语义会变成陷阱。
4. **公开面与测试矩阵的成本**。`RuntimeLocal` 需要第二个解析入口(VM 发起)与第二套失效
   规则,而父文档 §3.5 的四个目标场景全部是 context 作用域:宿主内建函数/构造函数缓存(per context)、
   native 对象在各 context 的 JS 包装(恰恰是每 context 一份)、JS 提供的长期回调、宿主 API
   注册表。没有一个需要第一版就跨 context。

对父文档 §7 问题 3 的直接回答:**引用计数 + 自动清理**成立(§2.3),**显式 `invalidate` 保留**
(§2.5);第一版公开 **ContextLocal**。原问题中"初步倾向前者"的两半因此都有了定论。

### 6.3 `RuntimeLocal` 的将来形态(不返工承诺)

- identity 布局不变:`registryID` 由 registry 自铸,粒度对 handle 不可见;
- registry 的槽位/泵/结算实现按"一个绑定 + 一个 settle context"参数化,不写死"context 就是
  容器";
- 将来新增的是 **mint/resolve 入口**,不是新 handle 类型。若走"锚 context"方案,
  前提取决于 §6.2 第 1 条能否在不引入第二 realm 的前提下解决。
- 跨 context 解析若要开放,必须同时解决"非创建 context 解析时的 root 归属",这会改变 §5.3
  的 claim/root 组合——因此它属于新能力,不属于 v1 的放宽(openQuestions)。

### 6.4 v1 公开 API 面

```swift
// 创建
public protocol JSContext: Actor, Hashable {           // actor;值必须属于本 context
  func makePersistentHandle(_ value: borrowing Value) -> PersistentHandle
}
public protocol JSInstantContext: JSValueScope, ~Copyable {  // 回调窗口
  @available(*, noasync)
  func makePersistentHandle(_ value: borrowing CallbackValue) -> PersistentHandle
  @available(*, noasync)
  func makePersistentHandle(_ value: borrowing Value) -> PersistentHandle
}
public protocol JSScope: JSValueScope, ~Copyable {           // 手动 scope
  @available(*, noasync)
  func makePersistentHandle(_ value: borrowing CallbackValue) -> PersistentHandle
  @available(*, noasync)
  func makePersistentHandle(_ value: borrowing Value) -> PersistentHandle
}

// 恢复:见 §5.1
// 释放:handle.invalidate()(§2.5)

// 约束:所有入口的类型都由 context 固定(`JSContext` 是锚点,scope/值把它的
// PersistentHandle/Value 别名过来);JSPersistentHandle 自身不声明关联类型。
// ContextHandle 的相等性用于校验 value.contextHandle == driverContextHandle。
```

语义细节:

- **mint 前置条件**:`value.contextHandle == driverContextHandle`(context 级绑定不接受
  其它 context 的值),否则 `preconditionFailure`(与既有工厂失败路径一致)。
  scope 见证侧另外要求箱子中存在 registry(直接构造的 `JSInstantContext(handle:)`、或箱子被
  外部清空 → `preconditionFailure`,消息指明"需要 hosted JSContext");actor 侧始终可用
  (registry 由 actor 持有,§3.1)。
- **mint 失败模式**:`claim`/root 的 driver 方法不可失败(`claimOwnedValueHandle` 返回非可选),
  因此 mint 不返回 `JSResult`。引擎侧"值本身是异常对象"不需要特殊处理——handle 绑定的是值,
  不是异常状态。
- **跨隔离域**:`Sendable` 是 handle 存在的理由。从外部铸造的标准写法是"在同步窗口内铸造并
  只把 handle 带出来",因为本地值不能离开隔离域(Stage 3 已实测的三类诊断,
  `Tests/SwiftJavaScriptEngineTests/EngineScopeContractTests.swift` 的负面样例注释块):
  ```swift
  let handle = await context.withInstantContext { scope in
    scope.makePersistentHandle(scope.makeString("value"))
  }   // scope 关闭,临时值结算;handle 继续可用
  ```
  直接写 `await context.makePersistentHandle(context.makeString("x"))` 不成立:内层调用的
  `JSValue` 结果不能返回到 nonisolated 上下文。
- **resolve 的产物同样不能离开隔离域**:`JSContext.resolve` 返回 `JSValue`(非 Sendable),
  因此它天然用于"在 actor 内解析并消费"。外部需要结果时,在同一窗口内转换/编码为
  Sendable 类型后返回。

### 6.5 分叉与取舍

| 分叉 | 选择 | 被否决方案及理由 |
|---|---|---|
| 粒度 | ContextLocal | RuntimeLocal:结算需要活 context、JSC root 为 context 寻址、realm 差异、无目标场景 |
| 公开类型 | 单一 `JSPersistentHandle` 协议 | 两个类型(`ContextHandle`/`RuntimeHandle`):语义分叉进类型层,Stage 4 返工 |
| 强度 | 仅强引用 | `.weak`:§4.4,引擎无安全判定 |
| mint 校验 | context 身份相等 | `isContextCompatibleWith`:group 级兼容会放进跨 realm 的值 |
| 创建入口 | `makePersistentHandle` | `persistAsHandle`:与 `persist`(转移语义)混淆;`make*` 与既有工厂一致 |

---

## 7. 与 Stage 3 成果的接面

### 7.1 分工表

| 需求 | 手段 | 生命周期 | 早期释放 | 跨隔离域 |
|---|---|---|---|---|
| actor 内的普通值 | 默认 scope(`makeString`/`getGlobalProperty`/`evaluateScript`) | context | 否(到 deinit) | 否(`JSValue` 非 Sendable) |
| 回调窗口内的临时值 | `JSInstantContext` 工厂 | scope 窗口 | 是(scope drain) | 否 |
| 显式提升、留在 actor 内 | `persist` → 默认 scope | context | 否 | 否 |
| 宿主长期持有 / 跨域传递 / 需要失效 | `JSPersistentHandle` | binding | **是**(`invalidate`) | **是** |

一句话:**默认 scope 是便利层,handle 是显式层**。默认 scope 不能替代 handle(不能早释放、
不能跨域、死亡无信号);handle 也不替代默认 scope(多一次槽位 + claim/root,阈值低但非零)。

### 7.2 resolve 的锚点:默认 scope 的累积问题与批量写法

- `JSContext.resolve` 锚在默认 scope:重复解析会持续累积 protect/引用,直至 context 死亡——
  与默认 scope 的既有累积问题同源(`TODO.md` §2.5 ①)。这不是新缺陷,但必须写进文档。
- 批量/循环解析的正确写法是进入同步 scope:
  ```swift
  let total = await context.withInstantContext { scope in
    var sum = 0.0
    for handle in handles {
      guard let value = scope.resolve(handle) else { continue }
      sum += value.toNumber(in: scope)     // JSValue.toNumber(in: borrowing JSInstantContext)
    }
    return sum          // scope 关闭时全部副本随 arena drain
  }
  ```
  这条也解释了为什么 resolve 必须提供在 `JSInstantContext`/`JSScope` 上,而不只是 actor 上。
- **不**为 `resolve` 新建临时 arena:没有 ambient 帧可挂;新建帧的返回视图必然悬垂。

### 7.3 `persist` vs mint(转移 vs 复制)

| 维度 | `persist`(既有) | `makePersistentHandle`(本设计) |
|---|---|---|
| 语义 | 转移:源 arena `takeFirst` → 目标 `track` | 复制:registry `claim` + root,源不动 |
| 源值之后 | 契约上不再使用(视图可能悬垂) | 仍有效,直到其 scope 关闭 |
| 目标 | 默认 scope(或显式指定的 scope) | registry 槽位 |
| 引用次数 | 不变(移动) | +1(JSC protect / QuickJS dup) |
| 早释放 | 无 | `invalidate` |
| 跨域 | 否 | 是 |
| 失败 | 无(兜底 claim) | 无(前置条件) |

同一回调里两者可以并存:`persist` 把值留在 context 里给后续 actor 调用用;
`makePersistentHandle` 把身份交给宿主。实现上二者共用的只有 `claimOwnedValueHandle`
(§2.2 的兜底路径)与 `ScopeFrame.track`,没有第二套引用纪律。

### 7.4 两份账本的不变量

```
每个 owned 引用恰好属于一份账本:
  本地视图 → 某个 ScopeFrame 的 arena(drain/ takeFirst 结算)
  binding  → registry 槽位(close / pump 结算)
两份账本之间只有 claim(复制),没有转移。
```

由此得到两条实现纪律:

1. resolve 必须 `claim` 后立刻 `track`(§5.3),不允许"先返回视图、稍后补记";
2. mint 不允许从 arena `takeFirst`(那就是 `persist`),否则源窗口的值会在用户手里变悬垂。

验证方式:Mock 的释放账本可以精确断言"每次 claim 对应一次 release",与
`contextReleaseLog`/`contextRootingLog` 的既有口径一致(`contextReleaseLog` / `contextRootingLog`,`Tests/SwiftJavaScriptTests/JSEngineCoreTypesTests.swift`)。

### 7.5 回调、类桥与异步预留

- **回调**:`JSCallbackReturn` 的三态与 trampoline 的引擎侧引用交接(父文档 §7 问题 2 的定案)完全不受影响;
  mint 是额外的一份引用,与 handoff 无关。
- **类桥**:`JSClass` 实例转换产物也是本地值,经同一 `makePersistentHandle` 路径 mint;
  `ContextLocal` 与"每个 context 一份 JS 包装"的目标场景天然一致
  (`VALUE_MANAGEMENT_REFACTORING.md` §3.5)。
- **异步桥接(非目标 1)**:异步 scope 已规划为 `explicitRoots`(父文档 §3.7);handle 与它正交——
  promise 结算前的中间值仍由异步 scope 记账,不需要 handle 参与。

### 7.6 分叉与取舍

| 分叉 | 选择 | 被否决方案及理由 |
|---|---|---|
| 默认 scope 与 handle | 并存,分工明确 | 用 handle 取代默认 scope:每次 `makeString` 都要槽位 + 锁,便利层退化 |
| resolve 锚点 | 调用方见证(actor → 默认 scope;scope → 自己) | 统一锚默认 scope:回调里的批量解析泄漏到 context 死亡 |
| 与 `persist` 的关系 | 两个动词,复制 vs 转移 | 复用 `persist` 名字做 mint:语义冲突不可接受 |

---

## 8. 测试与验收口径

> **本次未运行任何构建或测试。** 以下为 Stage 4 实现完成后必须执行的验收口径;
> 本设计期仅在 `/tmp` 下用 `swiftc -typecheck` 验证了 §1.2/§2.3/§2.4 引用的语言特性。

### 8.1 Mock 单元层(`Tests/SwiftJavaScriptTests`)

需要先补一项测试基础设施:当前 Mock 的 `claimOwnedValueHandle` 是 identity,无法建模 QuickJS
的 dup(`MockContextHandle.claimOwnedValueHandle`,`Tests/SwiftJavaScriptTests/JSEngineCoreTypesTests.swift`;这正是 `TODO.md` §2.5 ④ 登记的缺口)。
新增 `claimLog`(与 `contextRootingLog` 分开,避免把"申领"与"根化"混为一谈)。

用例(全部断言精确计数,不用轮询):

1. mint 一次 = 一次 claim + 一次 root;settle 一次 = 一次 unroot + 一次 release;
2. resolve 一次 = 一次 claim + 一次 track;scope drain 后该副本恰好释放一次,binding 仍可再次
   resolve;
3. `invalidate` → resolve 返回 nil;哨兵之后 settle 恰好一次;重复 `invalidate` 返回 false;
4. handle 不 `invalidate` 直接释放 → 哨兵之后 settle 恰好一次(证明清理是"经 executor 调度"
   而不是 deinit 内联);
5. 槽位复用:invalidate → 哨兵 → 新 mint 复用槽位 → 旧 handle resolve nil、新 handle 正常
   (generation 生效);
6. 容器消亡:context deinit 后每个 live binding 恰好 release 一次;之后 handle 的
   `invalidate` 为 no-op;旧 handle 在新 context 上 resolve 为 nil(`registryID` 生效);
7. **close 与 release 竞争**:在 close 进行中(或 close 前置位后)从另一线程丢 handle/调用
   `invalidate` → 每个绑定仍恰好结算一次(无漏结算、无二次结算);`close()` 重复调用幂等;
8. **外部清箱**:经 `installContextDataStorageBox(nil)` 从非 VM 线程清箱 → 不崩溃、不产生该线程
   上的引擎调用;registry 仍存活,actor 侧 mint/resolve 继续可用,scope 侧 mint 拒绝/resolve
   返回 nil;context deinit 时 close 仍恰好结算一次;
9. **finalizer 重入**:Mock 的 `releaseCreatedHandle` 钩子里丢弃一个 handle(模拟 QuickJS
   `JS_FreeValue` 同步执行用户 finalizer)→ 不死锁、不二次结算;
10. **状态机**:`settling` 期间任何 `release`/resolve 都 no-op;payload 不会被二次 move
    (以 Mock 的 payload 访问计数断言)。
11. 裸 context(无箱子):scope 侧 mint 触发 `preconditionFailure`(以独立失败探针/子进程验证;
    若不可测则以文档块保留,遵循既有编译期负面样例的处理惯例);actor 侧 mint/resolve 正常工作。

### 8.2 双引擎契约层(`Tests/SwiftJavaScriptEngineTests`,参数化 `ScriptEngine.allCases`)

1. 回调 mint → 经 JS 转发(`globalThis.f = ...` 保存)在后续回调中 resolve 并读取值;
2. actor mint → 后续 actor 调用内 resolve 可用(`toNumber` 精确);
3. **JSC GC 存活**:mint → 强制 GC(`JSGarbageCollect` 或等价)→ resolve 仍有效
   (证明 binding root 生效);
4. **QuickJS 计数回基线**:以 `JS_ComputeMemoryUsage` 的 `malloc_count`/`malloc_size` 为代理
   (Stage 3 既有口径),N 次 mint/invalidate + 哨兵后回到基线;N=1000 无增长;
5. 跨 context 解析 → nil(同 VM,两个 context);跨 VM 解析 → nil(JSC group 不同、
   QuickJS runtime 不同);
6. 容器消亡后:创建新 context 仍正常工作(证明 registry 的释放顺序没有破坏引擎状态);
7. `Sendable` 跨隔离域:`Task { handle }` 传递后经容器解析成功(正向);
   被否决的用法(不经见证解析)以文档块保留(编译期负面样例不可自动化,遵循
   `Tests/SwiftJavaScriptEngineTests/EngineScopeContractTests.swift` 文件头负面样例注释块的惯例)。

### 8.3 生命周期 / 线程层

- 用 FIFO 哨兵同步异步结算:`await IsolatedDeinitBarrier(virtualMachine: vm).ping()`
  (先例 `IsolatedDeinitBarrier`,`Tests/SwiftJavaScriptTests/JSEngineCoreTypesTests.swift` 的 `awaitContextTeardown`)。
- 断言清理发生在 VM 线程:与哨兵同形的顺序断言(settle 一定在 ping 之前完成);
  若实现能暴露执行线程标识,再加直接断言。
- **context 释放严格最后**:close 后立刻断言引擎仍可访问(例如在 deinit 后经同 VM 新 context
  执行脚本),证明 `releaseReference()` 没有被 registry 的 retain 拖后或提前;
- **迟到的泵**:close 之后强制让已调度泵执行,断言零引擎调用(Mock 计数 + 线程记录);
- ASan 满载轮:并发 `invalidate` + `resolve` + 容器销毁 + 外部清箱的交叉压力。

闭环(2026-11-23):§8.1 全部用例与 §8.3 的隔离断言、迟到泵均已落测试。"清理发生在 VM 线程"
不记线程标识,记执行器的隔离判据:Mock 的引擎调用钩子经 context 的 scope 栈绑定取到 `VMThread`,
记下 `isIsolatingCurrentContext()` 的真假——Mock 侧
`settlingSlotIgnoresReleaseAndResolveAndMovesPayloadOnce`(case 10)、
`contextDataStorageBoxSwapFromForeignThreadIsIsolatedToVMExecutor` / `contextDataStorageBoxSwapOnVMThreadIsInline`
(case 8 的外线程与内联两种形态)、`persistentSettlementEngineCallsAreIsolatedToVMExecutor`、
`selfOwningInputsReleaseIsolatedToVMExecutor`、`latePumpAfterCloseMakesNoEngineCalls`;双引擎侧
`contextDataStorageBoxSwapFromForeignThreadStaysOnVMThread`、`contextsOnABusySharedVMCanBeCreatedFromAnyThread`、
`selfOwningInputsDroppedOffTheVMThreadReleaseCleanly`;
QuickJS 内存基线 `quickJSPersistentHandleCycleReturnsAllocatorToBaseline`(§8.2-4)。
创建时刻的引擎调用(建 runtime、建 context、首次装箱)与 runtime 释放不在 Mock 的隔离记录里:
那时 context 还没有绑定,Mock 手里没有执行器;这四次的路由由代码结构(`VMThread.runAndWait`,
§3.5)与双引擎契约测试覆盖。

### 8.4 基准(`TODO.md` §2.6)

- mint / resolve / invalidate / 全部失效四组,分别测吞吐与尾延迟;
- 与"默认 scope 直接持有"对比(作为成本上限的参照,不是替代判据);
- 校准项:chunk 容量(32/64/128)、free list 形态、`Mutex` 争用、chunk 裁剪是否值得做。
  基准结论**只用于校准实现选型**,不用于决定"是否做"(与 Stage 4 原文一致)。

**实测(2026-11-23)见 §11**:JSC 与 QuickJS 双引擎真实数据、synthetic 表原型(槽位 vs
Dictionary)、pending 队列与 4 任务争用;选型结论见 §11.5。基准只覆盖数字(立即值)路径;
对象/GC 成本未测(见 §11.6)。

### 8.5 门禁

实现完成后依次执行并在 `TODO.md` 记录结果:

```
swift test
swift test --sanitize=address
swift format <改动文件>
```

外加文档一致性检查:公开面不出现 `.weak` 强度、不出现 `RuntimeLocal` 入口;§4.4 的
"弱引用验收条"已改写。

---

## 9. 分叉汇总

| # | 分叉 | 决定 | 一句话理由 |
|---|---|---|---|
| 1 | 命名 | `JSPersistentHandle` | 与既有 `JS*` 命名和"handle=身份"一致;避免与 `ref` 撞车 |
| 2 | 载体 | `final class`,真 `Sendable`,`Hashable` | deinit 驱动的最后 owner 释放;弱引用用内部 WeakBox 保持真 Sendable |
| 3 | identity | registryID + slot + generation | 引擎无关、ABA 安全、跨容器解析一次比较即失败 |
| 4 | mint 引用 | claim + root(复制) | 源值仍需可用;handle 可多次解析 |
| 5 | 清理 | 元数据即时失效 + executor closure 队列结算 | 任意线程不碰引擎;同一 OS 线程保证 resolve 不会被并发释放 |
| 6 | 清理负载 | 槽位持有 payload;任务携带 identity | 泛型 `~Copyable` 无法进 `@Sendable` 逃逸闭包(实测) |
| 7 | invalidate | 保留,幂等,异步结算 | 提前释放/断环/基准口径 |
| 8 | 挂载点 | actor 持有生命周期 + 箱子发布访问路径 | 回调内可同步到达;外部清箱只降级访问、不销毁 registry;零后端改动 |
| 9 | 表结构 | 分块 slab + free list | O(1)、可复用、内存有界;Dictionary 无这些性质 |
| 10 | 容器消亡 | `isolated deinit` 先 `close()`;无 deinit 兜底 | settle 需要活引擎;registry 可长于箱子且箱可被任意线程清空 |
| 11 | 替换 | invalidate + 重新 mint | 不可变 identity,避免值层 ABA |
| 12 | 弱引用 | v1 不提供,重写验收条 | 两个引擎都没有宿主侧安全弱引用 |
| 13 | 粒度 | ContextLocal | QuickJS 结算需活 context;JSC root 是 context 寻址;realm 差异 |
| 14 | resolve 锚点 | 见证自身(actor → 默认 scope;scope → 自己) | 本地值不能离开隔离域;批量解析用同步 scope |
| 15 | registry 的 context handle | 非 retain 值拷贝,close 后不解引用 | 保住 `releaseReference()` 在 VM 线程的最后释放;retain 会把 `JS_FreeContext` 挪到不可控现场 |
| 16 | 槽位状态 | 四态(含 `settling`) | 让"payload 已移出、结算未完成"可表达,防二次 move 与重入误判 |

---

## 10. openQuestions

1. **registry 的存放形态**:内部 `JSContextDataKey` + `setData`(会走 `any Sendable` 的类型擦除
   与 `ObjectIdentifier` 查表),还是在 `JSContextDataStorageBox` 上加一个 `package` 专用字段
   (类型更强、少一次向下转型)?需要基准/实现手感决定,不影响语义。§11.3 实测:box 访问使
   witness resolve 比 actor resolve 多 **254–288 ns/次**(约为 witness hit 的 40–45%);
   这是当前最大的一块可避免成本,若继续做优化,typed `package` 字段/缓存指针优先于换表结构。
2. **外部清箱后的访问路径**:`installContextDataStorageBox(nil)` 会移除 scope 侧入口(registry
   仍由 actor 持有)。是否需要在下次 mint 时自动重建/重发布?重建会让旧 handle 的 `registryID`
   失效(语义上正确但会无声杀死句柄);v1 选择"不重建、actor 侧继续工作",需要确认是否可接受。
3. **未 `close()` 的 registry 在 deinit 时的策略**:提案是 `assert` + release 构建下只泄漏引擎
   引用(不触碰引擎)。是否需要一个可观测的诊断(日志/计数器),以区分"程序错误"与"引擎已亡"?
4. **清理调度原语**:方案 (b) 需要改私有 executor 的状态机(加 closure 队列);
   方案 (a) 的 `Task(executorPreference:)` 首段线程语义是否需要运行时探针?若 (a) 成立且足够,
   可减少对 executor 的侵入。
   **已闭环(2026-11-23)**:(a) 成立且足够——SE-0417 原文写明任务创建即入队;执行器换为
   `ThreadAffinityExecutor` 库的 `DedicatedThreadExecutor` 后,闭包投递即
   `Task.detached(executorPreference:)`,不再侵入任何 executor 的状态机(§2.4 末)。
5. **`invalidate` 在 VM 线程上是否应内联结算**。当前无公开的"当前是否在 executor 上"判据;
   若要,需要 driver/executor 钩子。收益是少一个回合的延迟,代价是两条结算路径。
   **判据已存在(2026-11-23)**:`ThreadBoundExecutor.isIsolatingCurrentContext()`(§3.5),
   清箱路由已在用它;`invalidate` 内联结算本身仍未做,两条结算路径的取舍不变,登记于 `TODO.md`。
6. **槽位容量与裁剪**:chunk 容量、是否释放尾部空 chunk、`UInt32` 上限耗尽时的行为
   (`preconditionFailure` vs 自动扩到 64 位)。§11.4 实测:32→64→128 只把 insert 降低
   ~3–8 ns/op,lookup/release/churn 不变;v1 维持 32。另见 §11.5:泵的 `pending.removeFirst()`
   在队列填满时是 O(N²)(32,768 槽一次排空 29.4–30.0 ms vs head cursor 1.3 µs),应改为 head
   cursor/环形队列——这是尾风险,不是当前端到端热点(端到端 65,536 个 handle 同时失效仍是线性)。
   **已闭环(2026-11-23)**:`pending` 已改 head cursor + 摊还 O(1) 中途压实
   (`JSPersistentHandleRegistry.swift`);复跑 §11.1 双引擎 mass invalidation 单轮,斜率仍为零
   (JSC 913.8→929.8、QuickJS 924.2→941.1 ns/op,n=1,024→65,536;当日 1 分钟负载 71.5,
   绝对值高于 §11.6 历史区间属负载漂移)。
7. **弱引用的首个可实现子集**:class-backed finalizer 失效 vs JS 级 `WeakRef` 互操作,
   哪个先做?以及是否能覆盖"任意 evaluateScript 产物"这一最常用场景(目前看不能)。
   Stage 4 的"弱引用不阻 GC"验收条需要据此重写。
8. **typed host-value 存储**:是否需要 `ContextLocal<Value>(Value: Sendable)` 这类键值表
   (ThreadLocal 类比),还是 handle-only 足够?handle 只存 JS 值;宿主值可以放在
   `JSContextDataStorageBox` 的 `setData` 里,但那是 context 生命周期、不可提前释放。
9. **in-place rebind**:是否存在"身份必须跨替换稳定"的真实用例(例如类定义重建后宿主表项
   不换键)?若有,需要重新论证 `Hashable` 语义与线程归属。
10. **`isAlive` / `isInvalidated`**:是否需要在无容器的情况下查询绑定是否仍存活?
    v1 以"持有不授权访问"为由不提供,但它不是访问权,争议在于会鼓励"先查后解析"的竞态写法。
11. **同一 JS 值去重**:多次 mint 同一值是否应得到同一 handle(弱键身份表)?v1 每次一个 binding,
    成本是重复的 protect/dup;去重会引入"最后一个 handle 释放才结算"的引用计数 binding,
    与 §2.1 的简化冲突。
12. **跨 context 解析的将来形态**:若开放,`root` 归属与 unroot 的 context 需要新的记账规则;
    它与 `RuntimeLocal` 是同一个问题的两面,应一并设计。
13. **`JSPreparedScript` 式 context 保活的替代方案**:v1 明确不保活。是否有"宿主全局缓存但无
    context 属主"的用例需要"保活但没有解析权"?若有,可能是一个独立的 `JSPinnedValue` 概念,
    不应混进 handle。
14. **`JSOwnedValueManualReferenceCountedHandle` 是否需要 `Sendable`**:v1 不需要(清理任务不带
    payload)。只有当调度方案改成"闭包携带所有权"时才需要,届时需评估对全部 conformer 的影响。

---

## 11. 基准实测(Stage 4,2026-11-23)

> 本节只做**实现选型校准**(槽位 vs Dictionary、chunk 容量、泵队列、registry 访问路径),
> 不用于判断"是否做持久 handle 层"。基准只覆盖数字(立即值)路径;对象/GC 成本、ASan、
> `swift test` 不在本节范围内(见 §11.6)。

### 11.1 环境与可复现命令

| 项 | 值 |
|---|---|
| 主机 | Apple M1 Max,10 逻辑核,32 GiB |
| OS / 工具链 | macOS 27.2.1(26B131);Swift 6.4.2(swift-driver 1.168.6) |
| 构建 | `swift build -c release --product PersistentHandleBenchmarks` |
| 启动负载 | 六轮会话的 1/5/15 分钟 load average ≈ 7.1–26.8 / 13.0–18.0 / 26.0–34.6(见 §11.6) |
| 基准源 | `Benchmarks/PersistentHandleBenchmarks/{Harness,SyntheticTables,BenchmarkMain}.swift`;`Package.swift` 的 `PersistentHandleBenchmarks` executable target |

```sh
swift build -c release --product PersistentHandleBenchmarks
.build/release/PersistentHandleBenchmarks --jsc-only
.build/release/PersistentHandleBenchmarks --quickjs-only
.build/release/PersistentHandleBenchmarks --synthetic-only
```

JSC 与 QuickJS 各自在独立进程中运行,主数据取第一轮;另跑两轮做复现性检查(§11.6)。
synthetic 表原型跑四轮(三次独立 + 一次用本节 `--synthetic-only` 命令复跑;§11.4 报告
四次范围,表取第四次)。

### 11.2 方法

- **单位**:数字值。JSC 与 QuickJS 的 double 都是立即值,因此测量隔离了 JS 堆分配、GC 与
  finalizer,只覆盖 wrapper + registry + 引擎的 claim/root/settle。对象密集负载未测(§11.6)。
- **采样**:真实 registry 组 `samples=17`、`warmup=2`;mass invalidation 组 `samples=7`、
  `warmup=1`;synthetic 组 `samples=13`、`warmup=1`;4 任务争用 `samples=5`。
- **统计**:每个样本是同一批次 N 次操作的总时间除以 N;报告**中位数**、4000 次重采样的
  **95% bootstrap 中位数 CI**、均值 ± 总体标准差、CV、p10/p90。CI 描述的是本机当时的
  运行间波动,不是跨机保证。
- **配对**:候选与基线在同一 sample 槽内交替顺序运行(候选/基线/基线/候选……),降低热漂移;
  两者仍各自独立统计。
- **哨兵**:每样本新建 context(同一 VM),样本之间用固定在 VM executor 上的 FIFO 哨兵
  (`ExecutorBarrier.ping()`)等待 `isolated deinit`。实测哨兵单次往返约 **5.9 µs**;它同时
  进入 empty 与 loaded teardown,在差值中抵消。invalidate+settle 的计时包含哨兵,摊销后
  在 n=1,024 时约 5.8 ns/op(<1%),n≥8,192 时可忽略。`ping()` 必须是**有状态**的:实测
  空 actor 方法被优化成不跳线程(~4 ns),会让 teardown 差值恒为 0(§11.6)。
- **context 创建纪律**:`JSContext.init` 会执行 `JS_NewContext`,本身是引擎调用。基准先创建
  一个 bootstrap context(该 VM 上唯一在 cooperative 线程创建的 context),之后所有样本
  context 都经 `bootstrap.withIsolatedGlobalObject { JSContext(virtualMachine:) }` 在 VM
  线程创建。原因与一次可复现崩溃见 §11.6。(2026-11-23 起库自己把创建路由到 VM 线程,§3.5;
  本条的 bootstrap 做法只是当时的基准纪律,闭环见 §11.6。)
- **路径**:witness resolve 用公共 `JSScope.resolve`(与 `withInstantContext` 共用
  `resolvePersistentHandle` 和 context-data box);actor resolve 用 `JSContext.resolve`
  (直接持有 registry,产物锚默认 scope)。`invalidate miss` 在 VM 线程的 miss body 内测,
  与 resolve miss 同线程同 op 数;release 组的 invalidate 循环仍在 cooperative 线程跑,
  对应真实的跨线程提前释放。
- **mint 基线**:候选在同步 scope 内 `scope.makePersistentHandle(scope.makeNumber(...))`
  (源值随 scope drain,binding 存活);基线是 `isolatedContext.makeNumber(...)`(默认 scope
  直接持有:创建 + 显式根 + arena 入账,不能提前释放)。两者各取一份显式根;候选的额外成本
  是复制语义的 claim(JSC 恒等 / QuickJS dup)、槽位、handle 对象、registry 锁,以及调用方
  持有 handle 的数组入账。

### 11.3 真实 registry(JSC / QuickJS)

所有引擎数字为 **ns/op 中位数**;带 `[..]` 的是单轮 95% bootstrap CI。mass 表与
synthetic 表为宽度只列中位数,单轮 CI 宽度在段末说明(完整值在基准 stdout)。

**分配(mint / default scope hold,N = 16,384)**

| metric | JavaScriptCore | QuickJS |
|---|---:|---:|
| handle mint | 805.0 [801.7, 821.9] | 729.6 [725.2, 731.6] |
| default scope hold | 215.6 [215.3, 217.9] | 181.2 [181.1, 181.4] |
| mint − hold | **+589.5** | **+548.4** |
| mint / hold | 3.73× | 4.03× |

**resolve 与 registry lookup(N = 131,072 = 2,048 handles × 64 遍)**

| metric | JavaScriptCore | QuickJS |
|---|---:|---:|
| direct default-scope read | 54.4 [54.2, 54.8] | 6.7 [6.5, 6.7] |
| witness resolve(`JSScope`) | 649.9 [642.1, 651.3] | 596.8 [594.4, 600.4] |
| actor resolve(`JSContext`) | 386.4 [384.9, 394.0] | 342.5 [337.0, 347.1] |
| resolve miss(witness) | 539.8 [535.8, 542.9] | 507.7 [502.5, 515.8] |
| resolve miss(actor) | 252.1 [251.3, 254.2] | 254.0 [253.0, 255.9] |
| invalidate miss(VM 线程) | 146.6 [145.8, 150.1] | 150.2 [148.2, 151.1] |
| witness − actor(命中) | +263.5 | +254.3 |
| **witness miss − actor miss(box 成本)** | **+287.7** | **+253.7** |
| actor hit − actor miss(claim+默认 scope root+视图) | +134.3 | +88.5 |
| witness hit − witness miss(claim+隐式 track+视图) | +110.1 | +89.1 |
| **actor hit − direct read** | **+332.0** | **+335.8** |
| **witness hit − direct read** | **+595.5** | **+590.1** |

读法:

- 两个引擎的 **resolve 绝对增量几乎相同**(actor +332/+336,witness +596/+590),而 direct
  read 本身差 8 倍(JSC 54.4 vs QuickJS 6.7)。因此"resolve 是 direct 的多少倍"会误导
  (actor 7.1×/51×,witness 11.9×/88.8×);真正的结论是:**持久层自身的成本约 0.33 µs
  (actor)到 0.59 µs(witness),与引擎无关**,由 registry 锁、box 访问、claim/track 与
  `JSValue` 构造组成。
- **box 访问是 witness 路径最大的可避免成本**:witness miss 比 actor miss 多 287.7 ns(JSC)
  / 253.7 ns(QuickJS)。这直接回答 openQuestion 1:把 registry 从
  `JSContextDataKey` + `ObjectIdentifier` 查表换成 `JSContextDataStorageBox` 上的 typed
  `package` 字段(或 scope 侧缓存指针),有约 0.25–0.29 µs/resolve 的空间。
- 命中减未命中的差是 claim + track + 视图:JSC actor 134.3 / witness 110.1;QuickJS
  88.5 / 89.1。JSC 的 actor 路径多一次 `JSValueProtect`(默认 scope 是 explicit roots),
  QuickJS 的 root 是恒等;因此 JSC 的 claim+track 比 QuickJS 贵约 45 ns。
- metadata-only 的底价:`invalidate miss` 146.6/150.2 ns(弱引用加载 + 锁 + 槽位/代际检查),
  `resolve miss(actor)` 252.1/254.0 ns(同一查表 + 可选返回/`JSValue` 路径)。两者相差
  ~100 ns,属于 resolve 函数面(可选返回/额外一层)与测量差异,不是表结构。

**释放(N = 16,384)**

| metric | JavaScriptCore | QuickJS | JSC / default | QuickJS / default |
|---|---:|---:|---:|---:|
| invalidate + settle | 851.3 [848.5, 856.9] | 848.7 [846.2, 866.4] | 13.7× | 24.5× |
| last-owner deinit + settle | 652.4 [645.6, 659.4] | 726.7 [709.6, 734.2] | 10.5× | 21.0× |
| registry close at death | 213.3 [212.8, 214.7] | 198.6 [196.5, 204.1] | 3.4× | 5.7× |
| default scope teardown | 62.0 [61.9, 62.6] | 34.7 [34.6, 34.8] | 1× | 1× |

(default scope teardown 是 `(loaded context 析构 − empty context 析构) / N`;empty 与 loaded
都包含 ~5.9 µs 哨兵,差值中抵消。ratio 用各自 run 的 default teardown 作分母。)

**释放组的三轮中位数(同一命令重复三次;第一轮为上表点估计)**

| metric | JSC 三轮 | QuickJS 三轮 |
|---|---|---|
| invalidate + settle | 851.3 / 858.3 / 749.3 | 848.7 / 845.3 / 842.1 |
| last-owner deinit + settle | 652.4 / 612.3 / 549.5 | 726.7 / 677.3 / 690.2 |
| registry close at death | 213.3 / 213.3 / 213.6 | 198.6 / 189.8 / 188.8 |
| default scope teardown | 62.0 / 61.9 / 61.8 | 34.7 / 34.6 / 34.7 |

读法:

- **JSC 的释放绝对水平跨轮波动明显**(invalidate 749–858,deinit 550–652,约 13–19%);
  QuickJS 较稳(invalidate 842–849,deinit 677–727,≤7%)。close 与 default 在两引擎都很稳
  (≤5%)。**结论只用不受这一波动影响的排序与量级**:close < deinit < invalidate 在三轮
  两引擎都成立;handle 结算比 default scope 高一个量级。上表的 CI 只是单轮内中位数的
  运行间区间,不覆盖跨轮水平漂移。
- 提前释放的确定性代价很高:**invalidate 是默认 scope 延迟结算的 12.1–13.7×**(JSC)/
  **24.3–24.5×**(QuickJS),deinit 是 **8.9–10.5×**/**19.5–21.0×**,close 是 **3.4×**/
  **5.4–5.7×**。这主要是 registry 的逐槽锁、泵调度与 settle 协议的成本,不是引擎 free 的
  成本:数字是立即值,QuickJS `JS_FreeValue` 对立即值是 no-op;JSC 的 `JSValueUnprotect`
  仍要执行,但默认 scope 的 62 ns/value 基本就是它的代价,远小于 850 ns 一档。
- 三种结算路径的相对顺序在两个引擎一致:**close(213/199)< deinit(550–727)< invalidate
  (749–858)**。同一轮内 `deinit` 比 `invalidate` 便宜约 120–250 ns/op:两者都做 N 次
  metadata release,但显式 invalidate 每次都要经 handle 方法 + 弱引用加载 + 返回分支,
  且与泵并发热锁;deinit 由 ARC 批量触发,首个 release 调度泵。`close` 最便宜,因为它只在
  VM 线程一次扫描 + 逐槽 move/settle,没有跨线程与调度。
- 设计含义:**不需要提前释放时,让 handle 随容器 close 是最省的**;`invalidate` 买到的是
  确定性与断环,代价约 **0.54–0.65 µs/handle**(JSC)/**~0.65 µs**(QuickJS)(相对 close),
  外加比延迟结算多约 **0.69–0.81 µs**。
- `close` 的 213 ns/binding 仍显著高于默认 scope 的 62 ns(QuickJS 199 vs 35)。若要继续
  优化,目标是 close 的逐槽锁协议(一次锁收集 payload、锁外 settle、再一次锁登记),不是
  表结构。

**大量 handle 同时失效(1,024 / 8,192 / 65,536)**

| n | JSC invalidate+settle | JSC close | JSC default teardown | QuickJS invalidate+settle | QuickJS close | QuickJS default teardown |
|---:|---:|---:|---:|---:|---:|---:|
| 1,024 | 848.4 ns/op(0.869 ms) | 217.3 ns/op(0.223 ms) | 63.5 ns/op(0.065 ms) | 910.0 ns/op(0.932 ms) | 194.6 ns/op(0.199 ms) | 35.4 ns/op(0.036 ms) |
| 8,192 | 857.5 ns/op(7.025 ms) | 213.0 ns/op(1.745 ms) | 61.9 ns/op(0.507 ms) | 885.6 ns/op(7.255 ms) | 196.8 ns/op(1.612 ms) | 36.0 ns/op(0.295 ms) |
| 65,536 | 844.2 ns/op(55.33 ms) | 212.7 ns/op(13.94 ms) | 61.7 ns/op(4.05 ms) | 867.6 ns/op(56.86 ms) | 192.3 ns/op(12.60 ms) | 35.4 ns/op(2.32 ms) |

括号内是该批次的**总时间中位数**。单轮 95% CI 宽度约 ±0.5–3%(n=1,024 最宽;例如
65,536 的 invalidate,JSC [838.1, 846.3],QuickJS [848.4, 871.2]);跨轮漂移大于单轮 CI
(§11.6),所以不要只看一格 CI。读法:

- **端到端的 mass invalidation 是线性的**:同一轮内每 op 从 1,024 到 65,536 基本不变
  (第一轮 JSC 848→844、QuickJS 910→868;第三轮 JSC 755→745、QuickJS 886→846;同轮斜率
  ≤5%)。没有观察到 O(N²)。绝对水平跨轮会漂移(JSC 可达 ~13%,如 n=65,536 的
  745–844 ns/op),但**斜率为零这一结论在三轮两引擎都成立**。
  原因:invalidate 生产者(~0.5–0.6 µs/op 的 metadata + 弱引用)与泵消费者在 VM executor
  上交错,`pending` 队列深度保持很小,`removeFirst` 每次只搬少量元素。
- **但泵队列的 O(N²) 是真实的尾风险**:见 §11.4 的 synthetic 排空测试——若队列真的堆到
  32,768 项,`Array.removeFirst` 需要 **29.4–30.0 ms**,head cursor 只需 **1.3 µs**。
  当前基准的端到端路径没有把队列压满,不代表它不可能被压满(executor 被长任务占用、慢
  finalizer、批量 invalidate 来自被阻塞线程等)。**建议把 `pending` 改为 head cursor/环形
  队列**(见 §11.5),这是行为保持的改动。
  **已闭环(2026-11-23)**:head cursor 化落地后按 §11.1 命令复跑双引擎单轮
  (JSC `--jsc-only`、QuickJS `--quickjs-only`),mass invalidation 每 op 仍不随深度增长:
  JSC 913.78 [896.89, 930.34] / 930.18 [888.40, 935.87] / 929.77 [917.89, 944.81],
  QuickJS 924.24 [901.86, 1015.38] / 912.25 [899.69, 975.70] / 941.09 [915.64, 942.43]
  (ns/op,n=1,024/8,192/65,536,CV≤5.7%)——交错路径无回归,压满队列的最坏情况从 O(N²)
  变为 O(N)。当日 1 分钟负载 71.5(§11.6 历史区间 7.1–26.8),绝对水平偏高属负载漂移,
  斜率结论不受影响。
- `close` 与 default teardown 也随 n 线性;`close` 的每 binding 成本在两个引擎都稳定在
  0.19–0.22 µs,`default` 稳定在 0.035–0.062 µs。

### 11.4 synthetic 表原型(无引擎调用)

> 原型只测**元数据**:payload 是 `UInt64`,没有引擎 claim/root/settle。slot 原型镜像真实
> registry 的分块 slab + generation + free list(lookup 用 shift/mask,匹配真实容量为编译期
> 常量的访问形态);`dict-reuse-boxed` 用 `[UInt32: EntryBox]` + generation + free list,
> 是 `~Copyable` payload 在 `Dictionary` 下的公平形态(每条一个堆 box);
> `dict-monotonic` 是"简单字典"下界(单调 token、不复用、无 generation),因无界增长而不可
> 直接采用。**这些数字不能直接与 §11.3 的端到端数字相加**:真实层还包含锁、handle 对象、
> 弱引用与引擎调用。

**表结构(中位数,ns/op;文档命令 `--synthetic-only` 的第四次 run,N = 32,768,samples = 13)**

| table | insert | lookup hit | lookup miss | release | mint+release |
|---|---:|---:|---:|---:|---:|
| slot-32 | 54.27 | 18.35 | 11.82 | 42.32 | 87.71 |
| slot-64 | 45.97 | 18.38 | 11.87 | 42.44 | 87.77 |
| slot-128 | 42.57 | 18.29 | 11.87 | 42.31 | 87.76 |
| dict-monotonic | 41.85 | 18.36 | 7.46 | 35.58 | 24.90 |
| dict-reuse-boxed | 61.21 | 15.73 | 7.46 | 64.06 | 83.06 |

四轮独立 run 的中位数范围(单点离群只影响均值,见 §11.6):slot-32 hit 18.35–19.01;
slot-32 release 42.3–45.3;boxed hit 15.6–16.9;boxed insert 61.2–65.9;boxed release
64.1–67.6;monotonic hit 17.9–19.2;pending removeFirst 896.8–915.7。排序在四轮一致。
单轮 95% CI 半宽:上表各值大多 <0.5 ns(例如 slot-32 hit [18.31, 18.86]、boxed hit
[15.70, 15.76]);跨轮范围更能代表噪声,完整 CI 见基准 stdout。引擎进程内嵌的 synthetic
块(同一进程先跑 JSC/QuickJS)与独立 run 有 ±10% 以内的差异,排序相同;本节不把它们混入
上表。

差异(slot-32 − boxed,负值表示 slot 更快;同一轮配对):

| 维度 | slot-32 − boxed | slot-128 − boxed |
|---|---:|---:|
| insert | −6.9 | −18.6 |
| lookup hit | +2.6 | +2.6 |
| lookup miss | +4.4 | +4.4 |
| release | −21.7 | −21.8 |
| mint+release | +4.7 | +4.7 |

跨轮配对差的范围:insert −6.9 至 −13.5;hit +2.1 至 +3.2;miss +4.4 至 +5.1;release
−19.5 至 −23.6;churn +3.1 至 +7.4。

读法:

- **没有"槽位 lookup 更快"这回事**:在公平的 boxed+reuse 字典下,slot 的 lookup 反而慢
  2–5 ns(多读 chunk/generation/live 三个数组),因为 `Dictionary` 的整数键哈希很便宜。
  slot 的优势在 insert(−6.9 至 −13.5 ns,免去每条 box 分配)与 release(−19.5 至 −23.6 ns,
  免去 box 释放与字典删除);churn 基本持平(+3 至 +7 ns)。
- 这些差距相对真实层很小:lookup 的 2–5 ns 是 actor resolve miss(252 ns)的 1–2%、witness
  resolve hit(~600 ns)的 <1%;insert/release 的 7–24 ns 是 mint(~800 ns) / release
  (~850 ns)的 1–3%。**换表结构不会改变持久层的性能画像**。
- `dict-monotonic` 的 insert/release/churn(41.9/35.6/24.9)是最快的一组,但 lookup hit
  (18.4)仍慢于 boxed(15.7);而且它按累计 mint 数增长(token 空间与字典大小都只增不减),
  不能复用槽位,也没有 generation/ABA;只在"生命周期与容器同寿、且允许无界内存"的场景可
  考虑,不属于本层的候选。
- **容量 32→64→128**:insert 54.3→46.0→42.6(lookup/release/churn 不变)。收益来自更少的
  chunk 分配/数组 append;代价是新 registry 一次预留更大的 chunk(32/64/128 槽)。按 §6.4/
  §7.1 的目标场景(宿主缓存/每 context 包装,量级在数十到数百 handle),32 的内存更友好,
  而 mint 端到端 ~805 ns 下 8 ns 的差异约 1%。**v1 维持 32**;64 可作为 mint 密集型的可选
  校准,128 不推荐(收益再减半,预留翻倍)。

**pending 队列与争用**

| 测试 | 中位数 | 说明 |
|---|---:|---|
| pending drain,`Array.removeFirst`,n = 32,768 | 896.8 ns/op → **29.4 ms/次**(跨轮 29.4–30.0) | O(N²);当前 `pump()` 的形态 |
| pending drain,head cursor,n = 32,768 | 0.04 ns/op → **1.3 µs/次** | O(N);建议形态 |
| contended lookup,4 tasks,slot-32 | 52.5 ns/lookup | 10.24M lookups/sample |
| contended lookup,4 tasks,dict-monotonic | 56.2 ns/lookup | 10.24M lookups/sample |
| 单线程 slot-32 hit / dict-monotonic hit | 18.35 / 18.36 ns | 同上,无争用 |

读法:

- `Array.removeFirst` 每次移动剩余元素,32,768 项的排空是 **29.4–30.0 ms**(跨轮),
  是 head cursor 的 **约 2.3 万倍**。当前端到端 mass invalidation 没有触发它(§11.3),
  但这是一个明确的最坏情况。改为 head cursor(或 `Deque`/环形缓冲)即可消除。
- 4 任务争用下两张表都从 ~18 ns 涨到 ~52–56 ns(2.9–3.1×),差距只有 ~4 ns。**锁是瓶颈,
  不是表结构**。这与"resolve 只在 VM 线程、`Mutex` 串行化 metadata"的设计一致;如果未来
  cross-thread invalidate 流量上升,应先分片/改 pending 队列,而不是换 Dictionary。

### 11.5 选型结论

| 决策 | 结论 | 依据 |
|---|---|---|
| 表结构 | **保持槽位 slab + free list** | 元数据 lookup 比 boxed Dictionary 慢 2–5 ns,但 insert/release 快 7–24 ns;端到端差 ≤3%。真正的依据是:内存按峰值并发有界(而非累计 mint)、`~Copyable` payload 无需逐条 box、generation/ABA 在表内、无哈希/重哈希尾延迟 |
| chunk 容量 | **保持 32** | 32→64→128 只把 insert 降 8/3 ns,lookup/release/churn 不变;32 的内存粒度更适合数十到数百 handle 的宿主缓存 |
| pending 队列 | **已改为 head cursor**(2026-11-23;摊还 O(1) 中途压实,排空即整体重置) | `removeFirst` 在 32,768 深度是 29.4–30.0 ms;cursor 是 1.3 µs。改造后复跑双引擎单轮:mass invalidation 每 op 仍不随深度增长(JSC 913.8→929.8、QuickJS 924.2→941.1 ns/op,n=1,024→65,536),交错路径无回归;压满队列的最坏情况从 O(N²) 消除 |
| witness 访问路径 | **typed `package` 字段/缓存指针优先于换表** | box 访问 254–288 ns/resolve,是 witness hit(~600 ns)的 40–45%,也是当前最大的可避免成本 |
| 单 `Mutex` | **维持** | 4 任务争用把 lookup 从 ~18 推到 52–56 ns,两表同样;争用是锁,不是表。resolve 仅 VM 线程,单锁可接受 |
| 默认 scope vs handle | **并存;默认 scope 用于热路径与容器同寿值** | mint 贵 3.7–4.0×,结算贵 12.1–24.5×(invalidate)或 3.4–5.7×(close);handle 的溢价买的是提前释放、Sendable 与显式身份 |
| close / deinit / invalidate | **能延迟就 close;需要确定性才 invalidate** | close 188.8–213.6 ns/binding(JSC 213.3–213.6,QuickJS 188.8–198.6),deinit 549.5–726.7,invalidate 742.1–858.3;显式提前释放相对 close 约 +0.54–0.65 µs(JSC)/~0.65 µs(QuickJS) |
| free list 形态 | **不改**(LIFO `popLast`) | 本次未单独测;LIFO 复用最热槽位,O(1),没有反证 |
| chunk 裁剪 | **v1 不做** | 峰值并发驱动(chunk 数),不是累计 mint;裁剪是内存/延迟新权衡,本次未测 |

**槽位 vs Dictionary 的一句话结论**:在真实 registry 路径上,两张表的元数据差异被
`Mutex`、box 访问、引擎 claim/root 与泵协议压到 ≤3%;槽位胜在**有界内存 + 免逐条 box +
表内 generation**,而不是 lookup 速度。`Dictionary` 方案要公平比较就必须复用键、带
generation、并为每个 `~Copyable` payload 加 box——这三项恰好抵消了它 2–5 ns 的 lookup
优势。

**与 §7.1 的分工对照**:默认 scope 仍是热路径的便利层(创建 181–216 ns,结算 35–64 ns,
无提前释放/跨域);handle 是显式层(创建 ~730–805 ns,resolve 342–650 ns,提前释放
~850 ns,close ~199–217 ns)。不应把 handle 用在每值热循环;批量解析应在同步 scope 内完成
(§7.2),actor 侧重复 resolve 会持续累积默认 scope 引用,本次未测其累积成本。

### 11.6 噪声、局限与发现

- **负载与噪声**:机器非空载(六轮会话启动时 1 分钟 load average 7.1–26.8,5 分钟
  13.0–18.0,15 分钟 26.0–34.6);负载与单轮指标没有稳定对应(第三轮 1 分钟负载更高,
  JSC 释放反而更低)。真实 registry 组的单轮 CV 大多 ≤2.5%(个别 5.7%,见 deinit);
  synthetic 组大多 ≤5%。所有结论用中位数 + 95% bootstrap CI,不把均值当点估计。
- **复现性(三轮)**:allocation 与 resolve 稳定:JSC mint 805.0/806.3/781.0(≤3.3%)、
  witness resolve 649.9/663.3/642.0(≤3.3%)、actor resolve 386.4/405.1/391.0(≤4.9%)、
  miss 差异 ≤5.8%;QuickJS mint 729.6/707.2/716.8(≤3.2%)、witness resolve
  596.8/586.2/595.2(≤1.9%)、actor resolve 342.5/336.9/346.3(≤2.8%)、miss 差异 ≤4.4%。
  **JSC 释放组跨轮漂移约 13–19%**(invalidate 749–858,deinit 550–652),QuickJS 释放组
  ≤7.5%;close 与 default teardown 在两引擎都稳定(≤5.3%)。因此 allocation/resolve 可以用点
  估计 + CI 阅读;release 只用排序、量级与区间,不把单轮的 851 ns 当作精确值。§11.3 的
  释放表同时给出三轮中位数,§11.4 给出 synthetic 的四轮范围。第三轮使用最终 harness
  (修正 bootstrap 释放时序);前两轮只差收尾等待,计时路径相同,故合并报告范围。
- **单点离群**:synthetic 的一轮 `dict-reuse-boxed lookup miss` 与一轮 `pending removeFirst`
  出现单个异常样本,均值被拉高(SD 可达数百 ns,个别格 CV 32–47%),中位数与 CI 稳定;本节
  一律用中位数。这是为什么不用均值做点估计的实例。
- **`invalidate miss` 的线程**:最初在 cooperative 线程测,CV 14.5%;移入 VM 线程的 miss
  body 后 CV 1.3–1.9%。release 组的 invalidate 循环保留在 cooperative 线程,对应真实跨线程
  释放路径;不要把 146–150 ns(VM 线程死 handle)与 749–858 ns(跨线程 live invalidate +
  泵)混为一谈。
- **崩溃发现(基准纪律,不是基准结论)**:若样本 context 在 cooperative 线程创建,而同一
  QuickJS VM 上另一个 context 正在结算,基准可间歇复现 `EXC_BAD_ACCESS` in
  `JS_FreeContext` / `JS_RunGC`(lldb 捕获;退出码 133/139)。`JSContext.init` 在调用线程
  执行 `JS_NewContext`,而库的引擎访问不变量是"仅 VM executor"(§0.2.3);公开初始化器
  没有线程门。基准改为 bootstrap + VM executor 创建后,连续 5 次 QuickJS quick 运行与
  4 次 standard 引擎运行(JSC/QuickJS 各两轮)全部通过。**本片不修改库**;多 context 共享
  VM 的宿主代码应自行串行化 context 创建(登记为审计发现)。
  **已闭环(2026-11-23)**:`JSContext.init` 把 context 的创建经 `VMThread.runAndWait` 投递到
  VM 线程并等待,`JSVirtualMachine` 的 runtime 创建与释放同样路由,公开初始化器不再需要宿主
  自行串行化(§3.5)。契约测试 `contextsOnABusySharedVMCanBeCreatedFromAnyThread`
  (双引擎)覆盖"VM 线程正忙时从别的线程建 context"这一形态,debug / release / ASan / TSan
  全量通过。
- **空 `ping()` 的优化**:无状态 actor 方法的 `await` 被优化为 ~4 ns 的不跳线程调用,使
  teardown 测量假性归零;有状态 `ping()` 得到 ~5.9 µs 的真实跨线程往返。后续基准应直接
  复用 `ExecutorBarrier` 的有状态形态。
- **执行器更换后的复跑(2026-11-23,单轮)**:`JSVirtualMachine` 的执行器由自写的
  `DedicatedThreadSerialExecutor` 换成 `ThreadAffinityExecutor` 库的 `DedicatedThreadExecutor`,
  闭包投递由私有 closure 队列改为 `Task.detached(executorPreference:)`(§2.4 末)。按 §11.1 命令
  复跑 release 与 mass invalidation 两组。release:JSC invalidate+settle 868.30、last-owner
  deinit+settle 717.25、registry close 234.09 ns/op;QuickJS 872.14、698.99、196.81。
  mass invalidation:JSC 981.49 / 916.48 / 886.11,QuickJS 906.78 / 896.06 / 886.88 ns/op
  (n=1,024/8,192/65,536),不随深度增长。相对 §11.3 的自写执行器数字:invalidate 比原跨轮区间
  (742–858)高 1–17%(每次结算多一次 Task 分配);deinit 落在原区间内;JSC close 高约 10%,
  QuickJS close 落在原区间内。负载:JSC 轮 1/5/15 分钟 22.9/28.1/21.7,QuickJS 轮 11.0/22.7/20.3。
  **本节其余数字仍是自写执行器下测得的**;哨兵往返、teardown 差值这类直接依赖执行器的量
  未在新执行器下重测。
- **范围边界**:只测数字(立即值)路径。对象 mint 的 JSC GC / QuickJS 引用计数与 finalizer
  成本未测;`JS_FreeValue` 同步触发用户 finalizer 的重入(§3.5)是正确性问题,本次不测。
  `JSVirtualMachine` 析构、chunk 裁剪、free list 形态、跨线程 resolve(不允许)、
  ASan、`swift test` 均未运行。synthetic 用 `[UInt64]` 而非真实 registry 的
  `UnsafeMutablePointer` 存储,slot 的 lookup 可能被 bounds check 略微高估(几 ns 量级);
  不影响排序结论。

### 11.7 与 V8 §10.3/§12.4 的对应

V8 的持久 handle 文档讨论 `Persistent`/`GlobalHandles` 的创建、销毁、`HandleScope` 与
local handle 的分工,以及"在热路径上用 local、长期身份用 persistent"的取舍。本节的四组
(mint / resolve / release / mass invalidation)与这个语境一一对应,但也只做到**同构**:

- V8 的 `Persistent` 创建 ≈ 本层 mint(复制语义 + 容器侧 root);
- V8 的 `Local` 恢复 ≈ 本层 resolve(经见证 claim 一份新引用进接收 arena);
- V8 的 `Persistent::Reset`(重绑)≈ 本层 invalidate + 重新 mint(§4.3 拒绝 in-place
  rebind);V8 的弱持久 handle 在 v1 无对应(§4.4);
- V8 的 `HandleScope` 批量销毁 ≈ 本层 close(容器级 inline settle)。

**没有测量 V8 本身**,因此不给出与 V8 的数字对比或"性能相当"的结论。可以说的只有量级:
本层单次操作在 ~0.15–0.85 µs,批量结算在 0.07–56.9 ms(65,536 个),属于"可用于宿主
缓存/长期身份,不适合每值热循环"的一档——这与设计 §7.1 的分工一致。

---

## 附录 A:代码与文档索引

引用按 `文件` + 符号名给出:符号名不随编辑漂移,`rg` 可直接定位。本表不使用行号。

| 引用 | 位置 |
|---|---|
| `JSValue` 为非持有本地值 | `Sources/SwiftJavaScript/Surface/JSValue.swift` 的 `JSValue` |
| `JSCallbackValue` 的 `handle + ContextHandle` | `Sources/SwiftJavaScript/Surface/JSCallbackValue.swift` 的 `JSCallbackValue` |
| 回调结果按栈顶落账 | `Sources/SwiftJavaScript/Surface/JSValueOperations.swift` 的 `bridgeSurfaceCallbackResult` |
| `ScopeFrame.track/drain/takeFirst` | `Sources/SwiftJavaScript/ScopeCore.swift` 的 `ScopeFrame` |
| `ScopeCore` 与 `persist`(转移) | `Sources/SwiftJavaScript/ScopeCoreHandleSurface.swift` 的 `persistHandle`、`takeFirst` + `target.track` |
| 默认 scope 锚定与 claim 兜底 | `Sources/SwiftJavaScript/ScopeCoreHandleSurface.swift` 的 `persistHandle`;默认 frame 来自 `ScopeStackRegistry.defaultFrame` |
| `JSInstantContext` init/deinit(push/pop/drain) | `Sources/SwiftyJavaScriptCore/Surface/JavaScriptCoreScopes.swift`、`Sources/SwiftyQuickJS/Surface/QuickJSScopes.swift` |
| 裸 scope 的 `scopeFrame` | `Sources/SwiftJavaScript/Surface/JSScope.swift`、`Sources/SwiftJavaScript/ScopeCore.swift` 的 `scopeFrame` |
| arena chunk(raw pointer 存储) | `Sources/SwiftJavaScript/ScopeCore.swift` 的 `ScopeArenaChunk` |
| `ScopeStackRegistry`(静态表先例;VM 线程绑定所在) | `Sources/SwiftJavaScript/ScopeCore.swift` 的 `ScopeStackRegistry`、`ScopeStack.bind` |
| `JSContext` 默认 scope 与 isolated deinit | `Sources/SwiftJavaScript/JSContextStorage.swift` 的 `defaultScope`、`teardown` |
| `JSContext` 强持 VM | `Sources/SwiftyJavaScriptCore/JSCContext.swift`、`Sources/SwiftyQuickJS/QJSContext.swift` 的 `virtualMachine` |
| 箱子安装/绑定 | `Sources/SwiftJavaScript/JSContextStorage.swift`;`Sources/SwiftJavaScript/JSContextData.swift` 的 `JSContextDataStorageBox.bindContextOwner` |
| `JSScope` 的公共构造面 | `Sources/SwiftyJavaScriptCore/JSCContext.swift`、`Sources/SwiftyQuickJS/QJSContext.swift` 的 `makeScope()`;`Surface/JSScope.swift` 的 `package init(handle:)` / `open()` |
| VM 专用线程 executor 与 Owner | `Sources/SwiftJavaScript/VMThread.swift` 的 `VMThread`、`VMThread.Owner`(包装 `ThreadAffinityExecutor` 库的 `DedicatedThreadExecutor`) |
| 清箱的 VM 线程路由 | `Sources/SwiftJavaScript/JSContextData.swift` 的 `JSEngineRuntimeDriver.swapContextDataStorageBox(_:on:raw:)` |
| 生命周期的 VM 线程路由(创建、runtime 释放、自保活输入析构) | `Sources/SwiftJavaScript/VMThread.swift` 的 `VMThread.runAndWait` / `VMThread.perform`;`Sources/SwiftJavaScript/JSContextStorage.swift` 的 `init(virtualMachine:)`;`Sources/SwiftJavaScript/JSPreparedInputs.swift` 两个类型的 `deinit` |
| VM deinit(runtime 释放) | `Sources/SwiftyJavaScriptCore/JSCVirtualMachine.swift`、`Sources/SwiftyQuickJS/QJSVirtualMachine.swift` 的 `deinit` |
| 借用/拥有 handle 协议 | `Sources/SwiftJavaScript/JSManualReferenceCountedHandle.swift` 的 `JSValueManualReferenceCountedHandle`、`JSOwnedValueManualReferenceCountedHandle` |
| driver 的 release/claim/root/unroot 与箱子访问 | `Sources/SwiftJavaScript/Engine/JSEngineRuntimeDriverProtocol.swift` 的 `JSContextRuntimeDriver` |
| JSC 的 release/claim/root/unroot | `Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreEngineRuntimeDriver.swift` 的 `JSCContextHandle` 同名方法 |
| JSC 跨 context 兼容(group) | `Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreEngineRuntimeDriver.swift` 的 `JSCEngine.isContextCompatibleWith` |
| JSC 的清箱(`takeRetainedValue`) | `Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreEngineRuntimeDriver.swift` 的 `JSCEngine.installContextDataStorageBox(_:in:)` |
| JSC runtime handle(group 所在) | `Sources/SwiftyJavaScriptCore/JavaScriptCoreRuntimeHandle.swift` 的 `JSCRuntimeHandle` |
| QuickJS 的 claim(dup)/release/free | `Sources/SwiftyQuickJS/Engine/QuickJSEngineRuntimeDriver.swift` 的 `QJSContextHandle.releaseCreatedHandle` / `claimOwnedValueHandle` / `rootOwnedValueHandle` |
| QuickJS 的清箱(`takeRetainedValue`) | `Sources/SwiftyQuickJS/Engine/QuickJSEngineRuntimeDriver.swift` 的 `QJSEngine.installContextDataStorageBox(_:in:)` |
| QuickJS context handle 的 retain(`JS_DupContext`)/release(`JS_FreeContext`) | `Sources/SwiftyQuickJS/QuickJSHandles.swift` 的 `QJSContextHandle.retainReference` / `releaseReference` |
| JSC context handle 的 release(`JSGlobalContextRelease`) | `Sources/SwiftyJavaScriptCore/JavaScriptCoreContextHandle.swift` 的 `JSCContextHandle.releaseReference` |
| QuickJS finalizer 同步调用用户 `definition.finalize`(结算重入来源) | `Sources/SwiftyQuickJS/Engine/QuickJSEngineClassDriver.swift` 的 finalizer |
| `Mutex`(非递归;scope 栈与 context data 的既有选择) | `Sources/SwiftJavaScript/ScopeCore.swift` 的 `ScopeStackStorage.state`;`Sources/SwiftJavaScript/JSContextData.swift` 的 `JSContextDataStorageBox.state` |
| QuickJS runtimeID(后端身份先例) | `Sources/SwiftyQuickJS/QuickJSHandles.swift` 的 `QuickJSRuntimeIdentityRegistry` |
| `JSPreparedScript` 的保活形状(反例) | `Sources/SwiftJavaScript/JSScopeWitness.swift` 的 `JSScopeWitness`;`Sources/SwiftJavaScript/JSPreparedInputs.swift` 的 `JSPreparedScript` |
| FIFO 哨兵测试先例 | `Tests/SwiftJavaScriptTests/JSEngineCoreTypesTests.swift` 的 `IsolatedDeinitBarrier`、`awaitContextTeardown` |
| Mock 的 claim/root 口径与引擎调用的隔离记录 | `Tests/SwiftJavaScriptTests/JSEngineCoreTypesTests.swift` 的 `MockContextHandle` 同名方法、`contextReleaseLog` / `contextRootingLog`、`engineCallLog` |
| 负向编译样例惯例 | `Tests/SwiftJavaScriptEngineTests/EngineScopeContractTests.swift` 文件头的负面样例注释块 |
| Stage 4 待办原文 | `TODO.md` §2.6、§2.7 |
| 设计约束原文 | `docs/VALUE_MANAGEMENT_REFACTORING.md` §3.5、§3.7、§5 Stage 4、§7 问题 3 |

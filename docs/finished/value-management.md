# 值管理重构完成项

归档自 `TODO.md` 中已经完成的值管理架构重构（Stage 0–4、遗留收尾、执行器重构与清箱路由）。设计与定案见 `docs/VALUE_MANAGEMENT_REFACTORING.md`、`docs/PERSISTENT_HANDLE_DESIGN.md`；过程记录见各阶段提交信息。

## Stage 0：`ScopeCore` 收口

- [x] `makeString(from:)` 下沉到 `ScopeCore`，`JSInstantContext`/`JSScope` 只留转发
- [x] `JSScope` 能力面显式化为语义最小面（不提供回调出口语义）
- [x] `JSScope` arena 生命周期测试
- [x] `JSCallbackReturn` 初始化器访问级复核
- [x] JSC 桥 persistent 回调返回补 `JSValueUnprotect` 配平

## Stage 1：作用域栈迁至 context + 值操作 context 寻址

- [x] 作用域栈从线程 TLS 迁到 context 寻址的 `ScopeStackRegistry<E>`；`TLSCallbackStack`/`threadDictionary` 删除
- [x] `JSCallbackValue` 内嵌 `ContextHandle`，不再查 ambient context
- [x] 引入 `JSScopeWitness` 协议；删除 `getProperty`/`setProperty` 内的临时 `JSInstantContext`
- [x] `JSCallbackValue` `~Copyable` 化，handle 收敛为 `package`
- [x] 同步 scope 的构造与值操作标注 `noasync`
- [x] 引擎结果 handle 按 context 栈顶落账（修复 QuickJS `getProperty`/`call` 结果的引用泄漏）
- [x] 嵌套契约测试（引擎级 JS 中转 + Mock 级同 context 嵌套）

## Stage 2A：handle 借用/拥有拆分与直接存储

- [x] handle 拆为借用 token（`ValueHandle`）与所有权载体（`OwnedValueHandle: ~Copyable`）
- [x] `ScopeArena` 改为持有 owned 元素的分块 `UnsafeMutablePointer` 栈
- [x] `JSValue`/`JSCallbackValue` 直接存储 `handle + ContextHandle`（删除 storage words）
- [x] JSC/QuickJS 各拆出 owned handle 变体
- [x] QuickJS 句柄判等升级为全位 identity
- [x] 双 free 负面编译样例

## Stage 2B：driver 协议分解与 context 实例方法化

- [x] driver 实例要求迁到 `ContextHandle`（`JSContextRuntimeDriver` 等五个协议），引擎协议保留为描述符
- [x] 值操作签名 owned 化重扫（结论：零签名变更）
- [x] `SendableMetatype` 退役；`JSValueConversionEngine` 收窄为转换并集
- [x] Mock 以单一 `MockContextHandle` 承载五个协议

Source breaks：公共转换协议的 requirement 约束由 `E: JSEngine` 改为 `E: JSValueConversionEngine`；`JSEnginePropertyDriver` 静态默认实现删除；`JSEngine` 不再蕴含 `SendableMetatype`；值操作入口迁到 `ContextHandle` 实例方法（引擎静态面暂留为转发目标）。

## Stage 3：`JSValue` 本地值化

- [x] `JSValue` 去 owning 语义（非持有本地值）
- [x] `ScopeCore` 编译期 `Rooting` 策略（同步 scope 隐式栈根，默认 scope 显式根）
- [x] `JSContext` 默认 scope（栈底）
- [x] `persist` 重定义为创建引用转移；QuickJS +1 泄漏与异常借用锚缺陷消除（§7.2）
- [x] `JSCallbackReturn` 三态统一借用语义
- [x] converter 与宏生成模板对 owning 语义的依赖清零
- [x] `JSValue`/`JSCallbackValue` 统一评估：暂不合并（§7.4），排期 Stage 5
- [x] `JSContext` teardown 改为 `isolated deinit`

Source breaks：`JSValue` 删除 `retainHandle`/`takeHandle`/`discard`/`init(retaining:)`/`init(taking:)`；`JSCallbackReturn(persistent:)` 由 `consuming` 改 `borrowing`；JSC 桥 `takeRef` 更名 `borrowedRef`；`JSContextRuntimeDriver` 新增硬 requirement `rootOwnedValueHandle`/`unrootOwnedValueHandle`/`claimOwnedValueHandle`；`bridgeHandleResult` 约束收紧为 `JSEngineRuntimeDriver`；QuickJS `globalObjectValueHandle` 改借用语义；平台下限升至 macOS 15.4；`JSContext` 析构异步化；`JSContext.virtualMachine` 提为 nonisolated。

## Stage 4：持久 handle 层

- [x] `JSPersistentHandle`（identity 化 `Sendable`，v1 强绑定）与 `JSPersistentHandleRegistry`（分块 slab + free list + generation）
- [x] 结算经 VM 线程调度；`close()` 在 `isolated deinit` 内联结算
- [x] 基准测试 `Benchmarks/PersistentHandleBenchmarks`
- [x] 契约测试（双引擎参数化 + QuickJS 单引擎 WeakRef）
- [x] `pending` 队列 head cursor 化
- [x] 设计 §8 验收口径全部落齐（状态机、线程层、QuickJS 内存基线测试）

## 执行器重构与清箱路由

- [x] 执行器换为 `ThreadAffinityExecutor` 库的 `DedicatedThreadExecutor`（core 内 `VMThread` 薄包装），闭包投递为 `Task.detached(executorPreference:)`；新增依赖 `swift-thread-affinity-executor`
- [x] `installContextDataStorageBox` 对托管 context 路由到 VM 线程（已在 VM 线程则内联）
- [x] `JSScope` 构造面收敛：`~Sendable`，`init(handle:)`/`open()` 降 `package`，公共面 `JSContext.makeScope()`

Source breaks：`JSScope.init(handle:)`/`open()` 降为 `package`；新增 `JSContext.makeScope()`；非 VM 线程发起的箱子交换变为异步生效；VM 线程上的工作项改为严格 FIFO（闭包不再优先于已排队的 job）。

## 线程归属收口

- [x] `JSContext.init` 与 `JSVirtualMachine.init` 的引擎侧创建（建 context、读箱装箱、建 runtime）经 `VMThread.runAndWait` 投递到 VM 线程并等待；`JSVirtualMachine.deinit` 的 runtime 释放同样路由
- [x] `JSPreparedScript` / `JSPropertyStringKey` 在创建时记下 `VMThread`，析构经 `VMThread.perform` 路由
- [x] `isolated deinit` 把 scope 栈的 pop 挪到最后一步，VM 线程绑定覆盖清箱与 context 释放
- [x] Mock 测试里引擎调用的线程记录改为执行器的隔离判据（`isIsolatingCurrentContext()`）
- [x] 契约测试：忙的共享 VM 上从别的线程建 context；自保活输入在别的线程析构

Source breaks：无。行为变化：在非 VM 线程构造 `JSContext` / `JSVirtualMachine` 会阻塞到创建在 VM 线程上完成。

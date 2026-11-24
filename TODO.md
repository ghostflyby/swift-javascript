# TODO

本文件只保留仍需执行或仍需约束的事项。已完成的大段历史已按主题归档：

- [Core API、测试与宏完成项](docs/finished/core-api-tests-and-macros.md)
- [引擎迁移完成项](docs/finished/engine-migration.md)
- [清理与基线完成项](docs/finished/cleanup-and-baselines.md)
- [值管理重构完成项](docs/finished/value-management.md)

## 0. 基线与流程

- [ ] 每次实现前更新本文件中的进行中条目
- [ ] 每完成一条能力立即打勾并补充简要说明

## 1. 多引擎架构迁移

### 1.1 InstantContext 收口待办

#### P2（可选）

- [ ] 评估对象/数组快速构造 builder 的收口价值，若仅单点使用则不推进

#### 非收口边界（显式约束）

- [ ] 保持 `JSValue`/`JSObject` 的用户语义 API 不下沉（初始化器形态、转换器选择、错误映射等）
- [ ] 保持 `JSClassDefinition` 元编程组装不下沉（descriptor 组装与导出语义留在定义层）

### 1.2 将 `JSValue` 迁移到 `SwiftJavaScript`

第 6 步收尾约束（context/VM 语义）：

- [ ] 约束A：区分 Home Context 与 Operation Context。Home Context 仅负责值生命周期（protect/unprotect、takeRef retain）；Operation Context 仅负责 API 执行。
- [x] 修复 JSC callback 返回值 ownership handoff：`callbackRef()` 消费 wrapper 并跳过 `JSValue.deinit -> JSValueUnprotect`，补 Mock deinit/release 计数与跨引擎 callback 回归测试（已完成，`swift test` 通过）（2026-11-22 复核补遗：当时只配平了 QuickJS 侧；JSC 桥 persistent 返回缺 `JSValueUnprotect` 对称处理、每次泄漏一个 protect，已在 Stage 0 收尾补上）

### 1.3 引擎泛型标记

优先级策略（避免与 `JSValue` 主线互相干扰）：

- [ ] 先完成 `JSValue` 迁移收尾，再展开全链路引擎泛型标记改造（避免两类大改叠加导致回归定位困难）

阶段 A：先改 core，不改 facade 用户 API

- [ ] 在 `SwiftJavaScript` core 层补齐引擎泛型约束，先覆盖 handle/result/driver 协议签名（进行中：conversion 协议去引擎参数化）
- [ ] 保留过渡兼容层（typealias/adapter）以确保当前 `SwiftyJavaScriptCore` API 与测试面稳定

阶段 B：按垂直切片迁移，逐段收口

- [ ] Slice 2：基础判型与基础转换链路泛型化
- [ ] Slice 3：`JSObject` 属性访问链路泛型化
- [ ] Slice 4：`JSClass` callback 输入输出链路泛型化

阶段 C：收尾

- [ ] 删除过渡兼容层与旧路径
- [ ] 在 `SwiftJavaScriptTests` 增加“跨引擎误用应在编译期失败”的测试样例

### 1.4 剩余 JSC -> Core 迁移清单（按步骤）

边界约束：

- [ ] 不迁移 `JSContextRef/JSGlobalContextRef/JSObjectRef/JSClassRef/JSStringRef/JSPropertyNameAccumulatorRef`、`JavaScriptCore.JSStaticValue`、`JavaScriptCore.JSStaticFunction` 本体；这些仍属于 JSC facade/backend 的原始桥接边界
- [ ] 仅迁移这些原始类型之上的引擎无关组装逻辑、结果桥接模板与可复用的定义投影逻辑
- [ ] 不以“搬空 facade”为目标；后续迁移以“core 暴露接口/模板，JSC 保留具体实现”为准
- [ ] 保留在 JSC 的内容包括：raw ref 生命周期、`JavaScriptCore.JSClassDefinition` / `JSStaticValue` / `JSStaticFunction` 字段写入、`JSObject*Callback` 接线、`JSObjectGetPrivate` / `JSObjectSetPrivate` / exception pointer 读写
- [ ] 迁移到 core 的内容包括：definition 组装规则、static member 查找模板、auto storage 状态计算、与具体引擎无关的 callback 前后置模板（已删除冗余 static/definition installation plan，仅保留 callback flags）

#### Step 3：继续下沉 `JSClass` 的定义组装逻辑

- [ ] JSC facade 继续保留 `kJSClassDefinitionEmpty`、`JSClassCreate/Retain/Release`、`JSClassDefinition` 字段赋值和各类 `JSObject*Callback` 接线，只消费 core metadata + callback flags（已删除冗余 static/definition installation plan）
- [ ] 审查 `JSClass.borrow(ctx:)`、`JSClass(ref:)`、registry 与 raw lifecycle 周边是否还能进一步收口为 “JSC handle wrapper + core definition metadata/flags” 结构，避免 facade 同时承载定义模型和 raw class 生命周期

#### Step 4：继续下沉 `JSClassValueConvertible` 的 auto glue

- [ ] 从 `Sources/SwiftyJavaScriptCore/JSClassValueConvertible.swift` 中继续迁移 auto native definition 的引擎无关组装步骤：auto storage 访问模板、definition 选择策略、callback 前后置模板（进行中：auto storage 的 `usesManagedParent` / `finalizeDepth` / typed instance 模板，以及 backing/storage 的 definition 选择模板已下沉到 core）
- [ ] 将 `JSClassValueConvertible` 中剩余可通用的 callback 前后置模板继续下沉到 core，只保留 `JSObjectInitializeCallback` / `JSObjectFinalizeCallback` / `JSObjectGetPropertyCallback` / `JSObjectSetPropertyCallback` / `JSObjectCallAsFunctionCallback` 等 JSC C callback 接线（进行中：dynamic property 默认语义已下沉到 core；继续收口 static get/function call 的结果包装）
- [ ] 收口 `JSClassValueConvertible` 中仍直接依赖 `JSClass` / `JSPropertyNameAccumulatorRef` 的公开约束，优先改成 core 泛型接口 + facade 特化，而不是继续扩大 facade API 面

#### Step 4.5：拆分 class definition 的结构与行为

- [ ] 让现有 `JSClassDefinition<E, ...>` 导出并逐步消费新的 core definition，而不是继续把 metadata 和行为混在一个类型里（进行中：已把 `JSClassDefinition` 名称收口为完整协议，原纯 metadata struct 更名为 `JSClassDefinitionMetadata`，lookup / auto storage / converter helper 已开始按协议消费；`JSEngineClassDefinition` 暂仍作为默认存储实现，后续需继续收口命名与角色）
- [ ] 后续再把 callbacks 和 engine-bound static member implementations 从 class definition 本体中进一步拆离

#### Step 5：宏与公开文档去 JSC 硬编码

- [ ] 审查 `Sources/SwiftyJavaScriptCore/JSValueConversionMacros.swift` 中仍直接写死 `JavaScriptCoreEngine` / `JSClass` / `JSPropertyNameAccumulatorRef` 的说明与生成模板，优先改为引用 core converter/protocol 语义
- [ ] 补一轮面向 `SwiftJavaScriptTests` 的迁移测试，把新下沉的 `JSClass` / auto-convertible 组装逻辑优先放到 core 测试覆盖，避免继续只能在 JSC facade tests 中验证
- [ ] 为每一轮“core 接口 + JSC 实现”拆分补对应测试：core 侧测安装计划/解析模板，JSC 侧只测 raw callback wiring 与实际 JavaScriptCore 行为

### 1.5 QuickJS 作为边界验证器

原则：

- [ ] 新的 QuickJS 引擎实现模块只依赖 `SwiftJavaScript` 的 `public` API；不调用 `package` API，不复制 `SwiftyJavaScriptCore` 私有 helper（S15 复核：本轮未满足。QJS 仍经 `package` 的 `JSScopeWitness`/`JSSurfaceFactory`/`ScopeCore` 缝接线；保留为后续独立收口项，不在本片改写可见性。）
- [ ] 将后续“是否应继续迁移到 core”的判断切换为：QuickJS 最小桥接是否被迫需要新的 `public` API；若需要，再重构接线边界，而不是继续只按 JSC 形状推断
- [ ] 当 QuickJS 实现受阻时，只允许两类修正：提升真正通用的 `public` core API，或回退不合理抽象；不为 QuickJS 添加第二套私有兼容层

#### Step Q2：逐层验证 public 边界

- [ ] 补齐基础值构造、判型与基础转换；如果需要新接口，只提升到 `SwiftJavaScript public`
- [ ] 补齐 object/property 与 call/construct/invoke；继续以第二引擎实现作为接线边界的验真器（进行中：将 `JSValue` 收口为真正负责值句柄生命周期的 noncopyable 壳，并让 `QuickJSValueHandle` 改回普通 struct）
- [x] 对齐 QuickJS 与 JSC 的属性写入语义：`QuickJSEnginePropertyDriver.setValuePropertyHandle` 目前忽略 `JSHostMemberAttributes`，需要与 string-key 路径和 JSC 的 value-key 路径一样保留 `readOnly` / `dontEnum` / `dontDelete` 行为（已补 value-key/string-key shared tests，并让 QuickJS 默认 set 走 assignment、带 attributes 时走 define）
- [x] 明确并测试 propertyNames 的跨引擎契约：QuickJS 当前使用 `JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY`，JSC 使用 `JSObjectCopyPropertyNames`；需定义 own/inherited、enumerable/non-enumerable、string/index/symbol 的期望行为后再对齐实现（已收口为 `Object.keys` 语义：own enumerable string/index keys，不含 inherited/non-enumerable/symbol）
- [x] 对齐 QuickJS ArrayBuffer 创建失败路径：`JS_NewArrayBuffer` 返回 exception 时不应继续包装成普通 `QuickJSValueHandle`，并要释放已经 retain 的 deallocator box；JSC 路径当前会在 exception 时返回 `nil`（已在 QuickJS exception 路径返回 `nil` 并释放 deallocator box）
- [x] 补齐 QuickJS typed array 工厂：`makeTypedArrayHandle` 的 length / ArrayBuffer / ArrayBuffer+offset 三个重载目前返回 `nil`，导致 `JSTypedArray` 的公开初始化器在 QuickJS 上不可用；同时补跨引擎测试覆盖构造、kind、length、byteLength、byteOffset、buffer 与 bytes 访问（已用 `JS_NewTypedArray` 补齐并加 shared tests）
- [x] 校准 typed array bytes 指针契约：QuickJS `typedArrayBytesPtrForHandle` 当前返回 backing buffer 指针，JSC 使用 `JSObjectGetTypedArrayBytesPtr`；先定义 driver 应返回 buffer base 还是 typed-array view base，再修正 `JSTypedArray.withUnsafeBytes` 的 `byteOffset` 叠加逻辑并补非零 offset 共享测试（已用 shared test 确认为 backing buffer base，core 继续统一叠加 `byteOffset`）
- [x] 补齐 QuickJS host object / `JSClass` 边界：完成 runtime-independent `JSClassDefinition` 分层重构，让 common definition 不接收 runtime、不持有 runtime-bound `JSClass` parent，只在 `JSClass + RuntimeHandle` materialize 阶段解析 parent；本轮不混入 prototype inheritance / property enumeration 完整实现
- [x] 明确 QuickJS module 与 job queue 能力边界：capabilities 标记 `supportsESModules == true`，但当前 `evaluateScriptResultHandle` 仅按 global script 路径求值，且 `supportsPromiseJobQueueControl == false`；后续需决定是补 module evaluation/job pumping public API，还是降低/拆细 capability 标记（已将 `supportsESModules` 降为 false，并加 capability shared test）
- [ ] 后续重排线索：`JSEngineRuntimeDriver` 同时承担 runtime/context 生命周期、脚本求值、基础值工厂、函数工厂、判型与基础转换；可评估拆出 lifecycle/evaluation/value-factory/value-conversion 协议
- [ ] 后续重排线索：`JSEngineInvocationDriver` 同时承担 call/construct/toObject、Array/Date/instanceof 判定与 equality；可评估将 equality 与对象判型迁到 value/object semantics 协议
- [ ] 后续重排线索：`JSEngineTypedArrayDriver` 同时承担 ArrayBuffer 外部内存、TypedArray 构造、字节视图与类型判定；QuickJS 目前只有部分构造能力，适合按 capability 拆分 ArrayBuffer 与 TypedArray factory/introspection
- [ ] 后续重排线索：`JSEnginePropertyDriver` 混合 string/value/index 属性读写、删除、存在性检查与 propertyNames 枚举；可评估拆分 keyed/indexed property 与 enumeration 能力（已将 direct string-key witness 收敛为 literal-only `StaticString`；动态 `String` 需显式 `makePropertyStringKey`，后端仍可走 native static-string fast path）
- [x] 拆分 `JSString` 语义：移除公开 `JSString` / `JSStringManaged` / `JSStringValue`，改为 context-scoped `JSPropertyStringKey` 与 `JSPreparedScript`，并让 QuickJS property string key 使用 runtime/context 作用域 atom（已补充 string-key 命名，并增加 property string key 到 JS string value 的 native factory）
- [ ] 后续重排线索：`ClassHandle` 目前挂在 `JSEngineRuntimeDriver`，但 class/host object lifecycle 尚未形成独立能力协议；后续迁移 `JSClass`/host object 时需确认是否拆出 class bridge driver
- [ ] 最后再接 `JSClass` / callback / auto-convertible；到这一步再决定当前剩余 JSC-only 接线哪些真的应继续上收

#### Step Q3：测试策略

- [x] 为 QuickJS 增加最小共享行为测试，优先复用 `SwiftJavaScriptTests` 中已有的 engine-agnostic 覆盖（已扩展 `SwiftJavaScriptEngineTests`）
- [x] 将当前 shared engine tests 从 runtime/property/call 基线扩展到 ArrayBuffer/TypedArray、property attributes、function name/exception callback、Date/Array/instanceof、跨 context 兼容性；每项都同时跑 JSC 与 QuickJS
- [x] 按 `JSEngine` 组合协议来源重排 shared engine tests：`EngineRuntimeDriverTests`、`EnginePropertyDriverTests`、`EngineInvocationDriverTests`、`EngineTypedArrayDriverTests`、`EngineStringDriverTests`、`EngineValueConversionTests` 分别覆盖对应 public API 边界
- [x] 迁移更多 JSC-only public API tests 到 shared engine tests：`JSString`、`JSContext` thin wrapper、runtime/context identity、ArrayBuffer/TypedArray 细分行为、`JSValue` object/type helpers、`defineProperty`、codable/value converter 与 callback return/error coder；本轮迁移未暴露新的 QuickJS/JSC 行为不一致
- [ ] 每发现一处“JSC 迁移得来的边界不符合第二引擎实际”的案例，都在 TODO 里记录并据此调整剩余迁移优先级

## 2. 值管理架构重构

设计：`docs/VALUE_MANAGEMENT_REFACTORING.md`、`docs/PERSISTENT_HANDLE_DESIGN.md`。已完成的阶段见 [值管理重构完成项](docs/finished/value-management.md)。

### 2.1 待设计 / 待裁决

- [ ] 弱引用的后续子集：class finalizer 驱动失效、JS `WeakRef` 互操作（QuickJS 可行，JSC 待确认）——`PERSISTENT_HANDLE_DESIGN` §10-7
- [ ] 外部清箱后是否自动重建 scope 侧访问路径（v1 不重建）——§10-2
- [ ] 未 `close()` 的 registry 是否需要可观测诊断——§10-3
- [ ] `invalidate` 在 VM 线程上是否内联结算——§10-5
- [ ] chunk 容量、尾部裁剪、`UInt32` 耗尽策略——§10-6
- [ ] registry 访问路径：typed `package` 字段或缓存指针替代 context data box 查找（box 访问占 witness resolve 的 40–45%）——§10-1
- [ ] 后续能力：typed host-value 存储、in-place rebind、`isAlive`、同一值多次 mint 去重、跨 context 解析与 `RuntimeLocal`、context 保活替代——§10-8 至 §10-14

### 2.2 待实现

- [ ] 默认 scope 逃逸值累积：无提前回收 / compact API
- [ ] Stage 5（`@lifetime` 转正后）：本地值改 `Copyable + ~Escapable`；`JSValue`/`JSCallbackValue` 合并；`JSCallbackValue.decode` 去临时 scope；arena 降为释放记账
- [ ] `IsolatedDeinit` 实验特性转正后移除 `enableExperimentalFeature`
- [ ] 测试缺口：Mock `claimOwnedValueHandle` 为 identity，无法建模 QuickJS dup；缺 `persist(this/arguments)` borrowed fallback 用例
- [ ] 引擎静态操作面退役（方法体搬进 context 扩展）、类系统约束收窄、`JSFunctionCallback` 去引擎参数化
- [ ] `JSClass.deinit` 的 `JSClassRelease`（仅 JSC；QuickJS 侧为 no-op）仍在任意线程执行，未路由到 VM 线程
- [ ] 自保活输入（`JSPreparedScript` / `JSPropertyStringKey`）retain 引擎 context 但不 retain `JSVirtualMachine`：VM 先亡时 QuickJS 的 `JS_FreeRuntime` 与存活 context 引用的关系未验证

## 3. 协议化引擎实现迁移（JS*/JSC*/QJS*）

目标：core 只保留 JS* 协议与真正共用的 arena/作用域栈/默认 scope/持久 registry/转换实现；JavaScriptCore 与 QuickJS 各自提供 JSC*/QJS* 具体类型；值操作由具体类型直接调用本引擎实现。共享基础设施继续按引擎 E 参数化；S13 起只保留 JS* 协议 + JSC*/QJS* 具体类型，`*Legacy` 名称已退役。

- [x] 3.1 `engine-rename`：引擎标记、handle、facade 别名改为 JSC*/QJS*；行为不变，`swift test` 全绿。已完成（第 1 片）：`JSCEngine`/`QJSEngine` 与全部 `JSC*`/`QJS*` handle 落位，facade 保留 `JSCClassParentDescriptor`/`JSCAutoClassDefinition`/`JSCClassDefinitionModel`/`JSCManualNativeClassBacking` 薄别名，QJS 的 `gc()` 保留为 `QJSVirtualMachine` 专属面；旧名搜索已无命中。
- [x] 3.2 `free-surface-names`：把现有 core 用户面泛型类型改名为 `*Legacy`，释放 `JSValue`/`JSContext` 等最终名字；所有调用点、测试、宏字符串同步。已完成：core 15 个用户面泛型类型与 `JSFunctionCallback` 全部改为 `*Legacy`，对应文件用 `mv` 更名；JSC/QJS facade、宏生成字符串、四个 test target 与 benchmark 同步更新；`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均通过，Sources 下旧名仅剩 QuickJS C 结构 `CQuickJS*.JSValue` 引用。
- [x] 3.3 `protocol-surface`：新增 public JS* 协议、带 same1 等式的 `JSEngineSurface`、public `adoptCreatedHandle`/`anchorBorrowedHandle`、public `JSPersistentHandleIdentity`；package `JSSurfaceFactory`/成员只作 core 内部缝；MockEngine 用 `MockSurface*`（避开 MockContext/MockValue/MockClass）；`makeHandle` 改 `mintIdentity` 并更新 `JSPersistentHandle.swift:107/145/171`；`JSScopeWitness`/resolve 加 `where E: JSEngineSurface`；public `borrowHandle(in:)` 固定 ContextHandle 重载；JSCClass 在 S3 只保留 alias。已完成：`Sources/SwiftJavaScript/Surface/` 新增 17 个协议/seam 文件（15 个 JS* 协议 + `JSEngineSurface` + package `JSSurfaceFactory`），JSC/QJS 各建 14 个独立 shell 并在同一 conformance 中钉住全部 same1 等式（Class 保留 `JSCClass`/`QJSClass` alias），MockEngine 建 15 个 `MockSurface*`；`JSPersistentHandleIdentity` 提升为 public，registry 改 `mintIdentity` 且三处 legacy 包装改为 `JSPersistentHandle(identity:registry:)`；`JSScopeWitness` 升 package 并新增 `Value` + `makeValue(handle:)`（legacy 用 `JSValueLegacy`，surface 用 `E.Value`），resolve/mint 加 `where E: JSEngineSurface`；ScopeStack/ScopeStackRegistry/ScopeFrame/ScopeCore/JSScopeRooting/VMThread/EngineFactory/PersistentRegistryReference 逐个成员 package 化。验证：`swift build --target SwiftyJavaScriptCore`、`swift build --target SwiftyQuickJS`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`/tmp/planreview_probe2` 的 same1/cyc3/cyc4/vis5 typecheck exit 0、vis1/vis2/vis3/ident1/ident2 非 0；`rg` 无 `makeHandle`/`JSCClassLegacy`/legacy nested `Identity` 残留。`swift test` 与 `swift format` 按流程留给脚本执行。
- [x] 3.4 `value-core`：`JSCValue`/`QJSValue` 具体化；只做 decoder surface witness，`C` 用 S3 shell；encoder witness 留到 S7；JSValueHandleBridge/JSValueResultBridge 只新增 JSCValue 版本，legacy 版本保留到 S11。已完成：`JSValue` 协议补 `contextHandle`、`type()`、`toString()`/`toNumber()`/`toBoolean()`、八个判型与 `looselyEquals`/`strictlyEquals`（除 `type()` 外均为 `extension JSValue where Self: ~Copyable` 默认实现）；`JSCValue`/`QJSValue` 改为真实 `~Copyable` struct 并直接转调 `JSCContextHandle`/`QJSContextHandle`，`JSCEngine.Value`/`QJSEngine.Value` 已切换；新增临时 `JSValueDecodableSurface`/`JSValueDecoderSurface`（泛型 V/C 均带 `& ~Copyable`）及 Bool/Double/Int32/UInt32/String/Never witness，encoder 侧留 S7；`JSValueHandleBridge.swift`/`JSValueResultBridge.swift` 仅新增 JSCValue/`JSResult<JSCValue>` 版本；新增 `JSCValueCoreTests`、`QJSValueCoreTests`、跨引擎一致性用例与 `~Copyable`/Copyable conformer 默认实现用例。
- [x] 3.5 `value-object-invocation`：把属性、对象、调用、typed-array 判定等泛型转发移入两个引擎的值类型；`#isolation` 同名默认实现写成 `extension where Self: ~Copyable`，保住 `value.getProperty("x")`；`JSCodableValueConverter` 对象遍历留 S7。已完成：`JSValue` 协议新增 20 个 S5 要求（`getProperty`/`setProperty`/`deleteProperty`/`hasProperty`/`propertyNames`、`call`/`construct`/`invokeMethod`/`toObject`/`isArray`/`isDate`/`isInstanceOf`/`isArrayBuffer`/`isTypedArray`，统一 `in context: borrowing Engine.InstantContext`，属性 key 有 `StaticString` 与 `Engine.PropertyStringKey` 两个直接值入口，值与 `this`/constructor 参数直接接受 `Engine.Value` 与 `Engine.CallbackValue`（callback-value 重载只作 extension 便捷，不入 requirement））；core `Surface/JSValueOperations.swift` 提供同名 sync 默认实现（mock/test witness 复用）与 `isolated Engine.Context = #isolation` 便捷重载（iso2 形态，`/tmp/planreview_probe2/iso2.swift` typecheck exit 0），结果统一经 `bridgeSurfaceHandleResult` 在 scope arena / context 默认 scope 落账一次，异常路径同样 adopt；`JSCValue`/`QJSValue` 各建 `JSValueOperations.swift` 直接转调 `JSCContextHandle`/`QJSContextHandle` 并复用 S3 shell scope，未新增 encoder/`JSValueEncodable` 或 `JSCodableValueConverter` surface 版本。测试新增 `JSCValueOperationsTests`、`QJSValueOperationsTests`、`ValueOperationsCrossEngineTests`（覆盖 `getProperty`/`setProperty`/`call`/`construct`/`invokeMethod`/`isArray`/`isDate`/`isInstanceOf`/`isArrayBuffer`/`isTypedArray`/`toObject`/`looselyEquals`/`strictlyEquals`）、`SurfaceValueDefaultsTests` 的 `~Copyable` conformer `#isolation` 默认重载用例，以及 `surfaceValueOperationResultsAreTrackedAndReleasedOnce` 账本断言（drain 前零 release、每个结果恰好 settle 一次）。
- [x] 3.6 `callback-types`：`JSCCallbackValue`/`QJSCallbackValue` 等具体化，统一 `JSFunctionCallback`（含 @Sendable），`JSContextRuntimeDriver.Engine: JSEngineSurface`；保留 legacy driver requirement 并加具体引擎第二入口；函数回调初始化器移到 `JSCValue`/`QJSValue`；class 路径 JSArguments 留 S11；surface return/throw 测试留 S7。已完成：core 新增 `JSFunctionCallback<E: JSEngineSurface>`（`@Sendable`，参数/返回全用 surface 关联类型，`Surface/JSFunctionCallback.swift`）；`JSContextRuntimeDriver.Engine` 收为 `JSEngineSurface` 并保留 legacy `makeFunctionValueHandle` 要求、新增同签名 surface 重载（JSC/QJS/Mock 的 context handle 同时实现两者）；`JSCallbackValue`/`JSCallbackReturn`/`JSArguments`/`JSCallbackArguments` 补齐 `contextHandle`/`type()`/转换/判型/相等与 `isException`/`withValue`/`withThrowingValue` 身份操作要求，`JSArguments` 变长 `unpack`/`tryUnpack` 默认实现写在 `extension JSArguments where Self: ~Copyable`；core 新增 `bridgeSurfaceCallbackResult`（经 `JSSurfaceFactory.makeCallbackValue` 构造视图、每 handle 只 track 一次），legacy `bridgeCallbackResult` 与 class 路径保持不变。JSC/QJS 的 `JSCCallbackValue`/`JSCCallbackArguments`/`JSCCallbackReturn` 改为真实 `~Copyable` struct（`temporary`/`persistent`/`exception` 构造语义不变，回调窗口操作保留 `@available(*, noasync)`），JSC 增加 surface function class + 新 trampoline（legacy class/trampoline 保留），QJS 把 callback storage 统一为 legacy/surface 两态、新增 `quickJSSurfaceFunctionCallback`，`withQuickJSArguments` 切到新类型并保留 `withQuickJSLegacyArguments`；`JSValueInitializers.swift:141-239` 的函数回调初始化器移出 core，分别落到 `JSCValue`/`QJSValue` 扩展（使用 `JSFunctionCallback<Engine>`、`JSSurfaceFactory` 与 package `makeCallbackReturn`，错误路径构造 `JSCCallbackValue`/`QJSCallbackValue`），typed 与 coder 两种形式均保留。测试新增 `JSCCallbackSurfaceTests`/`QJSCallbackSurfaceTests`（回调值转换/相等、实参按索引访问、`try` 错误传播、`JSArguments` 变长解码），`EngineInvocationDriverTests` 增加 surface 第二入口端到端用例；`EngineValueConversionTests` 的 coder 初始化器用例改为 JSC/QJS 各跑一次；Mock 补两套 `makeFunctionValueHandle`。验证：`swift build`、`swift build --build-tests` 均 Build complete；`swift test --filter "JSCCallbackSurfaceTests|QJSCallbackSurfaceTests"`、`--filter "EngineInvocationDriverTests|EngineValueConversionTests"`、`--filter "EngineRuntimeDriverTests|EngineScopeContractTests|SurfaceConformanceTests|SurfaceValueDefaultsTests|JSEngineCoreTypesTests"`、`--filter "JSCValueOperationsTests|QJSValueOperationsTests|JSClassTests|JSClassValueConvertibleTests|PersistentHandleContractTests"`、`--filter "QuickJSContextTests|JSValueObjectInteropTests|JSClassDescriptorProjectionTests|JSValueAutoConvertibleMacroTests"`、`--filter "SurfaceValueDefaultsTests|ValueCoreCrossEngineTests|ValueOperationsCrossEngineTests|JSCValueCoreTests|QJSValueCoreTests|PackageSeamTests"` 全部通过。按流程未运行完整 `swift test` 与 `swift format`（脚本执行）。
- [x] 3.7 `scope-core`：`JSCInstantContext`/`JSCScope` 等具体化；共享 ScopeStack/ScopeFrame/ScopeCore 不重参数化；在 ScopeCore 上加 handle 级方法（adoptCreatedHandle/anchorBorrowedHandle/bridgeHandleResult），legacy 自由函数保留到 S13；成员逐个 package；切换 ScopeCore.makeFunctionValue/JSInstantContext.makeFunction/JSContext.makeFunction/installGlobalFunction 到新别名；class 回调留 S11；本片加入 encoder、JSCodableValueConverter 对象遍历与 return/throw 测试。已完成：core 新增 `JSValueScope`（两个 scope 共用的 driver + factories + persist + key 面）与 `JSInstantContext`/`JSScope` 的完整要求（factories/persist/return/throw/global/script/data/makePropertyStringKey/prepareScript，全部以 `Engine.Value`/`Engine.CallbackValue` 同型钉住），默认实现写在 `extension ... where Self: ~Copyable`；`ScopeCoreHandleSurface.swift` 新增 handle 级 package 方法（`makeStringHandle`…`makeArrayResultHandle`、`persistHandle`、`returnHandle`/`throwHandle`/`returnUndefinedHandle`/`throwUndefinedHandle`、`trackResult`、`globalObjectValueHandle`、`getGlobalPropertyValueHandle`、`makeFunctionValueHandle`、`makePropertyStringKeyHandle`、`makePreparedScriptHandle`、`evaluateScriptResultHandle`），`ScopeStack`/`ScopeStackRegistry`/`ScopeFrame`/`ScopeCore` 仍按 `E: JSEngineRuntimeDriver` 参数化且 legacy 自由函数保留；`JSCInstantContext`/`JSCScope`/`QJSInstantContext`/`QJSScope` 改为真实 struct（JSCScope/QJSScope `~Copyable, ~Sendable`），持 `ScopeCore<Engine, JSImplicitStackRoots>`，引擎关联类型、值/实参 scope 参数、`JSCValue`/`QJSValue` 简单值初始化器全部切换；`JSContext` 协议新增 `makeFunction`，三个 context shell 与 `installGlobalFunction` 默认实现走 `JSFunctionCallback<Engine>`（legacy `JSContextLegacy`/`JSInstantContextLegacy.makeFunction`/`ScopeCore.makeFunctionValue` 暂留 legacy 别名，因 `EngineScopeContractTests` 等 legacy scope 测试要求零改动，S13 随 legacy 删除）；encoder 面新增 `JSValueEncodableSurface`/`JSValueEncoderSurface`/`JSValueCodableSurface`/`JSDefaultConverterSurface` 与 Bool/String/Int32/UInt32/Double witness、`JSValueEncodable` 表面重载；`JSCodableValueConverter` 增加 surface 遍历（顺带修复 `NSNumber(1) as? Bool` 把 JSON 整数 1 读成 true 的既有顺序错误）。测试新增 `JSCScopeSurfaceTests`/`QJSScopeSurfaceTests`、`SurfaceScopeCrossEngineTests`、`SurfaceValueDefaultsTests` 的 ~Copyable encoder 默认实现用例、`PackageSeamTests` 的 surface package 方法调用，以及 `JSEngineCoreTypesTests` 的 5 个 surface 账本用例（adopt/anchor/persist move/borrow fallback claim/explicit root drain）。验证：`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`swift test --filter` 逐个 test target（SwiftyJavaScriptCoreTests 51、SwiftyQuickJSTests 37、SwiftJavaScriptEngineTests 71、SwiftJavaScriptTests 107）与新增用例全部通过；按流程未运行完整 `swift test` 与 `swift format`（脚本执行）。
- [x] 3.8 `context-vm`：`JSCContext`/`QJSContext`/`JSCVirtualMachine`/`QJSVirtualMachine` 具体化；共享 `JSContextStorage<E>`；补 Hashable、data box owner 擦除、`JSClass.borrow` 安全解包与新旧 owner 兜底；不迁移 benchmark/PersistentHandleContractTests；加“回调里 makeFunction 不崩”回归测试。已完成：core 新增 `JSContextStorage<E: JSEngineRuntimeDriver>`（`Sources/SwiftJavaScript/JSContextStorage.swift`，默认 scope + persistent registry + data box 安装/owner 绑定/数据存取 + teardown 顺序 registry.close → defaultScope.drain → box 清除 → release → pop）；`JSContext` 协议补齐 `virtualMachine`/`unownedExecutor`/`withInstantContext`/`makeScope`/值工厂/global/script/data，`JSVirtualMachine` 协议补齐 `driverRuntimeHandle`/`unownedExecutor`/`makeContextHandle`，两处均保持 `Engine` 参数化；`JSContextDataStorageBox` owner 擦除为 `AnyObject`（`bindContextOwner(_:)`/`borrowContextOwner()`，删除 `as: E.Type`）；`JSCContext`/`QJSContext` 改为 `public actor` 组合 storage + 具体 VM，`isolated deinit` 调 `storage.teardown()`，`JSCVirtualMachine`/`QJSVirtualMachine` 改为 `public final class`（VM 线程创建 runtime/context、nonisolated `==`/`hash` 用 runtime handle，`package vmThread`/`persistentCleanupScheduler` 供 core 接线，`QJSVirtualMachine.gc()` 新增）；`JavaScriptCoreContextHandle` 的 `functionClassRef`/`surfaceFunctionClassRef`/`propertyNamesFunctionRef` 改为经 data box owner 安全解析并同时接受 `JSCContext` 与 `JSContextLegacy<JSCEngine>`，`JSClass.borrow(ctx:)` 改为 guard + `as?`（禁止 `!`）；S3 的 `JSCContextShell`/`JSCVirtualMachineShell`/`QJSContextShell`/`QJSVirtualMachineShell` 删除，`JSCEngine`/`QJSEngine` 的 `Context`/`VirtualMachine` 关联类型切到新类型。测试新增 `JSCContextSurfaceTests`/`QJSContextSurfaceTests`（创建/拆除、data box、default scope 跨窗口存活、makeScope、Hashable/Equatable）、`JavaScriptCoreBackendDriverTests` 的 VM/context smoke 与“回调里 makeFunction 不崩”回归、`QuickJSContextTests` 的 surface 创建路径用例，并把 `JSCValueOperationsTests`/`QJSValueOperationsTests` 的隔离默认重载用例切到具体 context。验证：`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`swift test --filter "JSCContextSurfaceTests|QJSContextSurfaceTests|JavaScriptCoreBackendDriverTests|QuickJSContextTests"` 16+8 通过，`--filter "JSEngineCoreTypesTests|SurfaceValueDefaultsTests|JSCValueOperationsTests|QJSValueOperationsTests|PersistentHandleContractTests"` 79+13+4 通过，`--filter "EngineRuntimeDriverTests|EngineScopeContractTests|EnginePreparedInputTests|EngineInvocationDriverTests"` 30 通过，surface/scope/callback/conformance、class/interop/core-types、conversion/value 各批 filter 全通过。按流程未运行完整 `swift test` 与 `swift format`（脚本执行）。偏差：legacy `JSVirtualMachineLegacy where E == QJSEngine` 的 `gc()` 扩展保留（`quickJSClassBackedObjectRunsLifecycleCallbacks` 仍用 legacy VM），新 `QJSVirtualMachine.gc()` 为增量而非替换。
- [x] 3.9 `persistent-and-inputs`：`JSCPersistentHandle`/`JSCPropertyStringKey`/`JSCPreparedScript` 具体化；registry 继续按 E 参数化，mint 返回 public identity；统一给 JSContext/JSInstantContext/JSScope 加 makePersistentHandle/resolve 与 makePropertyStringKey/prepareScript；迁移 benchmark（`context.makeScope()`）、`stage4CollectGarbage`、PersistentHandleContractTests 与 EnginePreparedInputTests；所有泛型 helper 加 `_ engine: E.Type`。已完成：`JSPersistentHandle` 协议新增 `invalidate()`，`JSPropertyStringKey`/`JSPreparedScript` 升为 `Sendable` 并在协议 extension 提供 package 的 witness 版 `borrowHandle(in:)`；`JSSurfaceFactory` 的 persistent/key/script 构造改为 `(identity:registry:)` 与 `(handle:contextHandle:vmThread:)`（key/script 构造转移 handle 所有权并 retain context），共享释放算法抽到 `JSPreparedInputs.swift` 的 `releasePreparedInput`（legacy 与 JSC/QJS 共用）；`ScopeCoreHandleSurface` 新增 `makePersistentHandle`（CallbackValue/Value 两个入口，mint 走 registry）与 key/script 的 context+vmThread 接线；`JSContextStorage` 新增 `makePersistentHandle`/`resolvePersistentHandle`，`JSContext`/`JSInstantContext`/`JSScope` 协议加入 makePersistentHandle/resolve，JSC/QJS 的 context 与 scopes 全部落地。JSC/QJS 侧新增 `JSCPersistentHandle`/`QJSPersistentHandle`（public identity + weak registry + invalidate/deinit release）、`JSCPropertyStringKey`/`JSCPreparedScript`、`QJSPropertyStringKey`/`QJSPreparedScript`（handle + context + vmThread，deinit 经 VM 线程释放），删除 S3 三个 shell 并把 JSCEngine/QJSEngine 与 JSCContext/QJSContext 关联类型切到新类型。测试：`ScriptEngineAssertion.run` 改为 `<E: JSEngineSurface>`（全部 suite 同步），PersistentHandleContractTests 与 EnginePreparedInputTests 迁移到 `E.Context`/`E.VirtualMachine`/`E.PersistentHandle`/`E.Scope`，新增 surface 输入跨窗口存活用例；`stage4CollectGarbage` 改为 `E.VirtualMachine` + `QJSVirtualMachine` cast；BenchmarkMain 全量迁到 surface 并改用 `context.makeScope()`，所有泛型 helper 带 `_ engine: E.Type`。为让泛型测试/基准构造引擎类型，`JSVirtualMachine` 协议新增 `init()`、`JSContext` 新增 `init(virtualMachine:)`（JSC/QJS/Mock 均已实现）；MockSurfaceContext 加入内联 scheduler 的 registry，新增两个 ledger 用例（surface mint claim+root=1、resolve copy claim=1/释放=1、invalidate/close 单次结算）。验证：`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`swift test --filter` 四个 test target（SwiftJavaScriptTests 110、SwiftJavaScriptEngineTests 72、SwiftyJavaScriptCoreTests 60、SwiftyQuickJSTests 44）与 `PersistentHandleContractTests|EnginePreparedInputTests` 18 个用例全部通过。过程中修复了因 key 包装开始真正释放 atom 而暴露的 QJS PackageSeam 生命周期错序（自持有输入必须先于 runtime 释放）。按流程未运行完整 `swift test` 与 `swift format`（脚本执行）。
- [x] 3.10 `buffer-layer`：`JSCArrayBuffer`/`JSCTypedArray`/`QJSArrayBuffer`/`QJSTypedArray` 具体化；不新增 buffer encode conformance。已完成：core 的 `JSArrayBuffer` 协议补齐 `contextHandle`/`borrowHandle`/`withValue`、四个构造要求（`byteLength`/`copying [UInt8]`/`copying UnsafeRawBufferPointer`/`init?(value:in:)`）与 `byteLength`/`bytes`/`withUnsafeBytes`/`withUnsafeMutableBytes`（后四者及 typed-array 侧 `kind`/`length`/`byteLength`/`byteOffset`/`bytes`/字节访问默认实现全部写在 `extension ... where Self: ~Copyable`，`byteOffset` 叠加只在 core 一处）；`JSTypedArray` 增加 `Buffer.Engine == Engine`/`Buffer.Value == Value` 约束、`init(kind:buffer:in:)` 便捷重载与 `buffer` 要求。新增 `Sources/SwiftJavaScript/JSArrayBufferBytes.swift`（`jsArrayBufferBytesDeallocator`、零填充/数组/裸指针分配与 `adoptArrayBufferBytesNoCopy`：引擎拒绝时只释放一次字节并返回 nil）与 `JSArrayBuffer.remainingElementCount(from:kind:)`（open-ended typed-array 元素数共享算法）。JSC/QJS 各新增 `JSCArrayBuffer.swift`/`QJSArrayBuffer.swift`：两个真实 `~Copyable` struct 直接转调 `JSCContextHandle`/`QJSContextHandle` 的 typed-array driver，`buffer` 把引擎返回的 buffer reference adopt 到 context 默认 scope 一次；QJS 失败路径语义不变（driver 清 pending exception 并释放 deallocator box 一次，core 释放字节一次）。删除 S3 的 `JSCArrayBufferShell`/`JSCTypedArrayShell`/`QJSArrayBufferShell`/`QJSTypedArrayShell`，引擎关联类型与 `JSSurfaceFactory.makeArrayBuffer`/`makeTypedArray` 指向真实类型；Mock 补齐两个 witness 与共享 helper 调用。未新增 `JSArrayBuffer`/`JSTypedArray` 的 `JSValueEncodable` conformance。测试新增 `EngineBufferSurfaceTests`（arrayBuffer 往返/typedArray 形状/非零 offset 切片+回写/仅匹配值可包装，两个引擎各跑 4 例）与 `sharedArrayBufferByteHelperLedger`（接受路径 deallocator=1 且 drain settle=1，拒绝路径 deallocator=1 且零 adopt）。验证：`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`swift test --filter "EngineBufferSurfaceTests"` 4、`--filter "sharedArrayBufferByteHelperLedger"` 1、`--filter "EngineTypedArrayDriverTests|SurfaceConformanceTests|PackageSeamTests"` 7+4+4、四个 test target（SwiftJavaScriptTests 111、SwiftyJavaScriptCoreTests 60、SwiftyQuickJSTests 44、SwiftJavaScriptEngineTests 76）全部通过。按流程未运行完整 `swift test` 与 `swift format`（脚本执行）。
- [x] 3.11 `class-layer`：`JSCClass`/`QJSClass` 具体化；class 回调与 makeRememberedClassCallbackContext 本片切换；class 定义/桥接闭包改用 Engine.Value/Engine.InstantContext/Engine.Arguments/Engine.Class；去掉跨引擎 unsafeBitCast；`JSEngineClassBridgeDriver: JSEngineSurface`；`JSClassValueConverter`/`JSEngineClassDefinitionLookup` 同步；`JSMovedCoreTypesTests` closures 改用 `MockSurface*` 并同步 `JSClassDefinition` package helper。已完成：core 的 `JSClassDefinition`/`JSStaticValueDefinition`/`JSStaticFunctionDefinition`/`JSStaticValue`/`JSStaticFunction`/`JSClassParentDescriptor`/`JSEngineClassBehavior`/`JSEngineClassDefinition` 全部改为 `E: JSEngineSurface` 并以 `E.Value`/`E.InstantContext`/`E.Arguments`/`E.Class` 表达闭包（`JSClassParentDescriptor.classProvider` 返回 `E.Class`），`JSClassDefinition` 的 package helper（`callbackInstallationPlan`/`dynamicPropertyValue`/`setDynamicPropertyException`/`hasDynamicProperty`/`deleteDynamicProperty`）切到 surface 签名，缺省 undefined 走 `context.persist(context.makeUndefined())`；`JSEngineClassBridgeDriver` 基协议改为 `JSEngineSurface`，`makeClass`/`makeClassObjectResultHandle` 使用 `E.Class`，`JSEngineClassDefinitionLookup` 的 `E` 约束同步；`JSClassValueConvertible` 的泛型方法改为 `V: JSValue & ~Copyable, C: JSInstantContext & ~Copyable`（encode 返回 `C.Value`），删除 core 中跨引擎 `tryDecode`/`tryEncode` unsafeBitCast 重载，`JSClassValueConverter` 改为 surface 形状（其 engine-bound 方法与 engine-agnostic 的 surface converter 协议无法同签名，因此未声明 conformance）；`JSClassAutoNativeClassBacking`/`JSClassAutoObjectStorage`/`JSClassDefinitionLookup` 保持 core。JSC 侧 `JSCClass` 改为 `public final class`（持有 `JSCClassHandle` + `retainedOwner`，init retain 一次、deinit release 一次，Equatable/Hashable 按 handle，`ref`/`init(ref:)`/`init(defination:)`/`init(nativeDefinition:retainedBacking:)` 保留），`JSClass.swift` 的 registry、manual/auto definition 组装与 C 回调接线全部切到 `JSCClass`/`JSCValue`/`JSCInstantContext`/`JSCArguments`，`makeRememberedClassCallbackContext` 返回 `JSCInstantContext`，`classDefinition(for:)` 与 `JSEngineClassDefinition where E == JSCEngine` 的 `hostTypeDescriptor` 覆写保留；新增 `JSCStaticValue`/`JSCStaticFunction` 薄别名；`JSValueHandleBridge`/`JSValueResultBridge` 的 legacy `JSValueLegacy<JSCEngine>` 版本删除，S4 的 `JSCValue` 版本保留；`JSClassValueConvertible` 的 JSC 便捷 `tryDecode` 迁到 `extension JSCValue`（`JSCValue`/`JSCInstantContext`，无跨引擎强转）。QJS 侧新增真实 `public final class QJSClass`（handle retain/release 仍为显式 no-op），`QuickJSEngineClassDriver.swift` 的 class record/registry、exotic callbacks、static value/function callbacks 全切到 `QJSClass`/`QJSValue`/`QJSInstantContext`/`QJSArguments`（`JSClassDef.call = nil` 边界不变），`QJSEngine.makeClass`/`runtimeHandle(for:)`/`makeClassObjectResultHandle`/`classObjectPrivateData` 使用新签名；`JSCArgumentsShell`/`QJSArgumentsShell` 更名为最终名 `JSCArguments`/`QJSArguments`。测试：`JSClassTests`、`JSClassDescriptorProjectionTests`、`JSMovedCoreTypesTests` 改用 surface definition/`MockSurfaceValue`/`MockSurfaceInstantContext`/`MockSurfaceArguments`；`QuickJSContextTests` 的 4 个 class 定义与 6 个 class 用例迁到 `QJSValue`/`QJSInstantContext`（改用 raw runtime+context 的非 async 窗口以使用 `noasync` 回调入口，lifecycle 用例在 scope 退出后 `JS_RunGC`）。宏 class 路径输出 `JSCAutoClassDefinition`/`JSCStaticFunction`/`JSCValue`（`@JSClassFunction` 方法体的 legacy decoder 调用留 S14）。验证：`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`swift test --filter "JSClassTests|JSClassDescriptorProjectionTests|JSMovedCoreTypesTests"` 21、`--filter "QuickJSContextTests"` 11、`--filter "JSValueMacroDiagnosticTests|JSValueAutoConvertibleMacroTests"` 17、`--filter "JSValueObjectInteropTests|EngineValueConversionTests|SurfaceConformanceTests|JSEngineCoreTypesTests|JSCCallbackSurfaceTests|QJSCallbackSurfaceTests|PackageSeamTests"` 8+9+78+11 全部通过；`rg unsafeBitCast Sources/SwiftJavaScript/JSClass Sources/SwiftJavaScript/Surface` 无命中。按流程未运行完整 `swift test` 与 `swift format`（脚本执行）。
- [x] 3.12 `macro-facade`：宏生成 JSC* 具体类型/临时 surface 协议签名；facade 保留必要薄别名并删除冗余 JSC-only typealias。已完成：`@JSValueAutoSerialization` 改为生成 `JSValueCodableSurface` conformance（`init`/`tryDecode` 为 `V: JSValue & ~Copyable, C: JSInstantContext & ~Copyable`，另有 `toSurfaceValue`/`tryEncodeSurface`），属性/枚举成员全部经 `Self.__jsPropertyValue`/`__jsIndexValue`/`__jsObject`/`__jsArray` 使用 `driverContextHandle` + `adoptCreatedHandle` 的 public 路径读取/落账，转换器参数改为 `JSValueConverterSurface`/`JSValueDecoderSurface`/`JSValueEncoderSurface`；插件内已无 `JavaScriptCoreEngine`/`JavaScriptCoreContextHandle`/`JSValueLegacy`/`JSInstantContextLegacy`/`JSValueConversionEngine`/`unsafeBitCast` 字符串。`@JSClassAutoConvertible` 的 `jsClassDefinition` 输出 `JSCAutoClassDefinition`，属性/方法回调统一用 `JSCValue`/`JSCInstantContext`/`JSCArguments`/`JSCStaticFunction`/`JSCClass`，方法体改为 `arguments.withThrowingValue` + `context.return`/`throw`（core `JSArguments` 新增 public `withThrowingValue` 默认实现），回调 `this` 经 `anchorBorrowedHandle` 转成 `JSCValue`。facade 仅保留 `JSCClassParentDescriptor`/`JSCStaticValue`/`JSCStaticFunction`/`JSCAutoClassDefinition` 四个 public 薄别名及两个 internal implementation 别名，未发现可删除的旧名 JSC-only typealias；`QJSClassDefinition` 仍为 `JSEngineClassDefinition<QJSEngine, JSClassParentDescriptor<QJSEngine, Never>, Never>`。测试：`JSValueAutoConvertibleMacroTests` 11 个运行期用例与 6 个诊断用例迁到 `JSCInstantContext`/`JSCValue`/`JSDefaultConverterSurface`（17 passed）；`Support.swift`/`JSConversionSupport.swift` 的 `TestNumberMarshal`/`TestStringMarshal`/`TestBoolMarshal` 与 `ZeroOneBoolConverter`/`MacroDelegatedUser*`/`ReturnPayloadEncoder`/`FailurePayloadEncoder` 改为 surface witness；`JSClassTests` 新增 `macroGeneratedClassMethodsUseSurfaceCallbacks`（静态函数表、custom JS name、throwing 路径）；`JavaScriptCoreBackendDriverTests` 新增 facade 薄别名与 `JSCEngine.makeClass`/`makeValue` smoke；`SwiftyQuickJSTests` 新增 `quickJSClassDefinitionRemainsAThinAlias`。验证（本会话实际运行）：`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`swift test --filter "JSValueAutoConvertibleMacroTests"` 11 passed、`--filter "JSValueAutoConvertibleMacroTests|JSValueMacroDiagnosticTests|JSClassTests|JavaScriptCoreBackendDriverTests|quickJSClassDefinitionRemainsAThinAlias"` 1+31 passed、四个 test target 分别 111/64/76/45 passed。按流程未运行完整 `swift test` 与 `swift format`（脚本执行）。
- [x] 3.13 `retire-legacy-runtime`：删除 runtime 层 `*Legacy` 类型与旧泛型扩展；`ScopeCore` 收为 handle 级；明确 JSCValue/QJSValue 落账路径；先为 MockSurface* 做真实 ScopeCore/arena/registry 再迁移 Mock 测试。 已完成：core 删除全部 `*Legacy` 运行时类型/文件（JSValueLegacy、JSCallbackValueLegacy、JSCallbackReturnLegacy、JSArgumentsLegacy、JSCallbackArgumentsLegacy、JSInstantContextLegacy、JSScopeLegacy、JSContextLegacy、JSVirtualMachineLegacy、JSPersistentHandleLegacy、JSPropertyStringKeyLegacy、JSPreparedScriptLegacy、JSFunctionCallbackLegacy）及 legacy 自由函数/旧转换协议/旧 JSObject 便捷扩展；`ScopeCore.swift` 只保留 arena/ScopeStack/ScopeFrame + handle 级方法（adoptCreatedHandle/anchorBorrowedHandle/bridgeHandleResult/make*Handle/persistHandle/return|throwHandle/track/trackResult/globalObjectValueHandle/getGlobalPropertyValueHandle/evaluateScriptResultHandle/drain/frame），`VMThread`、`PersistentRegistryReference`+`resolvePersistentHandle`、`JSScopeWitness` 拆到独立文件，`EngineFactory`/`EngineLifecycle` 删除。JSC/QJS facade 删除 legacy trampoline/函数类、legacy 初始化器与 raw-ref 桥接，typed 函数初始化器改用 `JSValueDecodableSurface`/`JSValueEncoderSurface` 并走 `isolated JSCContext`/`QJSContext` 的 `makeFunction`。测试侧 `MockSurfaceInstantContext`/`MockSurfaceScope`/`MockSurfaceContext` 由真实 `ScopeCore`/arena/registry 支撑（Mock VM 改用真实 `VMThread` 作 executor 并绑定作用域栈），全部 core/engine/backend 用例迁到 `MockSurface*`/`E.Context`/`E.Value`（`ValueOnlyEngine` 用例改为 handle 级 + surface witness 约束测试，删除仅服务 legacy VM/自持有输入 mock 的 3 个用例）。验证（本会话实际运行）：`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`swift test --filter` 四个 test target（SwiftJavaScriptTests 106、SwiftJavaScriptEngineTests 76、SwiftyJavaScriptCoreTests 63、SwiftyQuickJSTests 44）全部通过；`rg "Legacy" Sources` 无命中。`swift format` 与完整 `swift test` 按流程留给脚本。
- [x] 3.14 `retire-legacy-class-buffer-and-conversion`：删除 buffer/class legacy；临时 conversion 协议改最终名；迁移/删除 `JSCodableValueConverter` 的 legacy 约束与 `JSValueConversionEngine`；宏字符串与宏测试期望同片更新。 已完成：临时协议改为最终名 `JSValueDecodable`/`JSValueEncodable`/`JSValueDecoder`/`JSValueEncoder`/`JSValueCodable`/`JSDefaultConverter`/`JSValueConverter`（Sources/Tests/Benchmarks 内 `*Surface` 协议名无残留），`JSValueConversionSurfaceImplementations.swift` 只保留一套 witness；`JSCodableValueConverter` 仅保留 surface 签名 conformance（`JSCodableValueConverterSurface.swift`，无 legacy 约束），`JSValueConversionEngine` 无声明/引用；buffer/class legacy 类型与 `JSCClassLegacy`/`JSCFunctionCallback` 过渡别名已在上一片删除，本片清理了 `EngineTypedArrayDriverTests.swift` 的旧名消息，并把整文件 `#if false` 的 `JSClassValueConvertibleTests.swift` 替换为可运行的 `JSCClassValueConvertibleTests.swift`（4 个用例改用 `JSCEngine.makeRuntimeHandle()` + `JSCInstantContext`/`JSCValue` + `tryEncode`/`tryDecode`）；宏插件与 `JSValueConversionMacros.swift` 使用 `SwiftJavaScript.JSValueCodable`/`SwiftJavaScript.JSDefaultConverter`，`JSValueMacroDiagnosticTests` 的现有期望文本不含 conversion 协议名，故无字面量需改。验证（本会话实际运行）：`swift build`、`swift build --build-tests`、`swift build --product PersistentHandleBenchmarks` 均 Build complete；`swift test --filter` 四个 test target 全部通过（SwiftJavaScriptTests 106、SwiftyJavaScriptCoreTests 67、SwiftyQuickJSTests 44、SwiftJavaScriptEngineTests 76），另 `JSValueMacroDiagnosticTests|JSValueAutoConvertibleMacroTests` 17、`jsClassAutoConvertible|JSClassTests|JSClassDescriptorProjectionTests` 16+3、`JSCodable|EngineValueConversionTests|SurfaceValueDefaultsTests|SurfaceScopeCrossEngineTests` 4+11 通过；`rg` 对 `JSArrayBufferLegacy|JSTypedArrayLegacy|JSClassLegacy|JSValueDecodableSurface|JSValueEncodableSurface|JSValueDecoderSurface|JSValueEncoderSurface|JSValueCodableSurface|JSDefaultConverterSurface|JSValueConversionEngine` 在 Sources/Tests/Benchmarks 无命中。完整 `swift test` 与 `swift format` 按流程留给脚本。
- [x] 3.15 `docs-verification`：更新 TODO/设计文档（含 JSEngineValueTypes 分层、public 落账原语、TODO.md:93 说明），全量 `swift test`、旧名搜索与 lifecycle 账本复核。已完成：本文件勾选 3.1/3.15 并补 §3.15.1；`docs/MULTI_ENGINE_BACKENDS.md`、`docs/MULTI_ENGINE_BACKENDS.zh-CN.md`、`docs/VALUE_MANAGEMENT_REFACTORING.md`、`docs/PERSISTENT_HANDLE_DESIGN.md` 的旧泛型/旧引擎名改为当前“public JS* 协议 + JSC*/QJS* 具体类型”模型，`docs/finished/` 作为历史归档保持原文；`JSEngineRuntimeDriverProtocol.swift` 顶部与 claim/root 注释写明 `JSEngineValueTypes` 只服务 handle 层、用户面必须 `JSEngineSurface`、无默认实现。全量 `swift test` 与 `swift format` 按编排约定留给脚本；本片实际执行 `swift build --product PersistentHandleBenchmarks` 与定向测试、搜索，结果见 §3.15.1 与最终回报。

### 3.16 去掉 `JSEngineSurface`：`JSContext` 作锚点，成员协议只做别名（已完成）

背景：3.3 引入的 `JSEngineSurface` 继承全部 5 个 driver 协议，用约 45 条同型等式把 15 个用户面类型钉在一起，约 20 个 `JS*` 协议靠 `associatedtype Engine: JSEngineSurface` 挂在它上面。本轮把它拆掉。

**约束结构的结论（Swift 6.4.2 实测）**

- “每个协议把自己的成员钉回 `Self`、成员之间互相钉”的写法不可用：分布式的 `== Self` 等式让类型检查不收敛（>60s）；在多个协议里重述 value↔scope 等式会让编译器栈溢出崩溃（`While checking generic signature <τ_0_0 where τ_0_0 : JSContext>`）。
- 可用的结构：`JSContext` 是唯一锚点，所有关系在这里各陈述一次、单向（context → 成员）；成员协议只声明 `associatedtype Context: JSContext`，并把自己用到的成员类型别名过去（`ValueHandle == Context.ValueHandle`、`Value == Context.Value` …），不陈述任何自己的关系。
- 给窗口加反向等式（`JSInstantContext` 的 `Context.InstantContext == Self`）同样让全量类型检查 150s 不收敛，所以没有加。后果写成规则（`JSContext.swift` 顶部注释）：涉及值的泛型代码以 `C: JSContext` 为根，窗口类型用 `C.InstantContext`/`C.Scope`；裸窗口类型（`S: JSInstantContext`）只能用自己的操作（工厂、global、脚本），不能把 `S.Value` 传给需要 `InstantContext` 的值操作。
- 解码签名因此改为以 scope 为单根：`init<C: JSInstantContext & ~Copyable>(value: borrowing C.Value, in context: borrowing C)`。原来的双根形式 `where V.InstantContext == C` 要求窗口被双向钉回 context，`JSDefaultConverter.decode<C>` 才能调用它。
- 编译器的顺序依赖：actor 在声明处内联写 `: JSContext` 时，如果同模块里排序靠前的文件先构造它（SwiftPM 的 module-emit 阶段会先检查那些函数体），`init(virtualMachine:)` 会被误报 `'nonisolated' on an actor's synchronous initializer is invalid`；把 conformance 放进 extension 则两种顺序都通过。`MockSurfaceContext` 用 extension 形式；`JSCContext`/`QJSContext` 所在模块内没有更早的文件触达它们的构造器，暂保持内联写法，遇到同样报错时照此改。

- [x] 句柄层机制改按 ContextHandle 泛型：`ScopeStack`/`ScopeStackRegistry`/`ScopeFrame`/`ScopeCore`/`JSPersistentHandleRegistry`（及其 Key）/`PersistentRegistryReference`/`JSContextStorage` 的类型参数由引擎 `E: JSEngineRuntimeDriver` 改为 `CH: JSContextRuntimeDriver`；`E.ContextHandle` → `CH`，`E.ValueHandle` → `CH.ValueHandle`，`E.OwnedValueHandle` → `CH.OwnedValueHandle`。`ScopeCore` 删除值级方法，只留 `trackCreatedHandle`/`claimAndTrackHandle`/`transferToDefaultFrame`/`trackOnDefaultFrame`；`JSContextStorage` 删除值级扩展。
- [x] `JSContextRuntimeDriver` 去掉 `associatedtype Engine: JSEngineSurface`，改为 `associatedtype InstantContext: JSInstantContext & ~Copyable`（不回钉 Self）；`makeFunctionValueHandle` 收 `JSFunctionCallback<InstantContext>`；`JSFunctionCallback<C: JSInstantContext & ~Copyable>` 按 InstantContext 泛型。
- [x] 成员协议只声明 `Context` 并别名：
  - `JSValue`：`ContextHandle`、`ValueHandle`、`InstantContext`；操作返回 `JSResult<Context.Value>`
  - `JSCallbackValue`：`ContextHandle`、`ValueHandle`；`JSCallbackReturn`：`ValueHandle`；`JSPersistentHandle`：无关联类型；`JSClass`：`ClassHandle`
  - `JSArguments`：`Value`、`InstantContext`；`JSCallbackArguments`：`Value`、`InstantContext`
  - `JSPropertyStringKey`/`JSPreparedScript`：`ContextHandle`、`Handle == ContextHandle.PropertyStringKeyHandle`（resp. `PreparedScriptHandle`）
  - `JSArrayBuffer`：`ContextHandle`、`Value`、`InstantContext`；`JSTypedArray` 加 `Buffer`
- [x] scope 协议：`JSValueScope` 声明 `ContextHandle`/`Value`/`CallbackValue`/`PropertyStringKey` 并新增落账原语 `adoptCallbackHandle`；`JSInstantContext` 声明 `CallbackReturn`/`CallbackArguments`/`Arguments`/`PreparedScript`/`PersistentHandle`；`JSScope` 声明 `InstantContext`/`PreparedScript`/`PersistentHandle`。值工厂、global 读写、脚本执行、data、encoder 版 `setGlobalProperty` 改为 core 的协议扩展默认实现（`JSScopeSurfaceDefaults.swift`），引擎 scope 只留落账原语、回调出口、`makeFunction`、持久绑定与 key/script 包装。
- [x] `JSContext` 成为锚协议：声明 `ContextHandle`/`ValueHandle`/`OwnedValueHandle`/`VirtualMachine`/`Value`/`CallbackValue`/`CallbackReturn`/`CallbackArguments`/`Arguments`/`InstantContext`/`Scope`/`PersistentHandle`/`PropertyStringKey`/`PreparedScript`/`ArrayBuffer`/`TypedArray`/`ClassHandle`/`Class` 并单向钉住，不再继承任何 driver 协议；值工厂、`makeFunction`、global、脚本、data 的默认实现建在 `adoptCreatedHandle` 与 driver 操作上。`JSVirtualMachine` 声明 `Context`/`ContextHandle`/`RuntimeHandle: Hashable`。
- [x] 删除 `JSEngineSurface`、`JSSurfaceFactory` 与 `ScopeCoreHandleSurface.swift`：值视图的构造留在引擎模块（scope/context 实现落账原语时直接构造）。
- [x] 转换协议与 class 层：`JSValueDecodable`/`JSValueDecoder`/`JSValueEncoder`/`JSValueEncodable` 统一以 scope 为单根；`JSEngineClassBridgeDriver` 改为 `Context: JSContext` + `Value`/`InstantContext`/`Arguments`/`Class` 别名（仍是引擎标记上的 package 缝，`JSCEngine`/`QJSEngine`/Mock 遵循）；`JSClassValueConvertible.decode`/`tryDecode` 与 `JSClassValueConverter` 的 where 改为 `C == T.Engine.InstantContext`；删除无调用方的 `bridgeSurfaceCallbackResult`。
- [x] 引擎模块：JSC/QJS 的每个具体类型去掉 `typealias Engine`，声明 `Context` 与所需别名；`JSCEngine`/`QJSEngine` 不再遵循 surface；scope/context 改为实现落账原语（`ScopeCore<JSCContextHandle, …>`/`ScopeCore<QJSContextHandle, …>`、`JSContextStorage<…ContextHandle>`、`JSFunctionCallback<…InstantContext>`）；持久 handle 的 mint 在两个 scope 间共用文件内私有函数。
- [x] 宏插件：`@JSValueAutoSerialization` 模板改用 `C.Value`/`C.ContextHandle.ValueHandle`/`C.ContextHandle.OwnedValueHandle`，`init`/`tryDecode` 改为单根签名，显式转换器分支不再需要先把值 anchor 成本引擎视图。
- [x] 测试与基准：`run<E: JSEngineSurface>` → `run<C: JSContext>`（`ScriptEngineAssertion`、benchmark、全部 suite），仅作类型标记的 `engine` 形参改名 `contextType`；Mock 改为以 `MockSurfaceContext` 为锚点（`MockEngine: JSEngineRuntimeDriver, JSEngineClassBridgeDriver` 作 class 桥）；conformance 检查改为“把引擎的具体类型传到 context 关联类型位置”的调用点 sink；`PackageSeamTests` 的值级 seam 改经 scope 协议默认实现；`bridgeSurfaceCallbackResult` 账本用例改为 `bridgeSurfaceHandleResult` 用例；手写 `JSValueDecodable`/`JSValueDecoder` 见证同步。
- [x] 文档：`docs/MULTI_ENGINE_BACKENDS.md`、`docs/MULTI_ENGINE_BACKENDS.zh-CN.md`、`docs/VALUE_MANAGEMENT_REFACTORING.md`、`docs/PERSISTENT_HANDLE_DESIGN.md` 的 `JSEngineSurface` 与 `Engine.` 参数化片段改为 context 锚点模型。
- [x] 验证（本会话实际运行）：`swift build`、`swift build --build-tests` Build complete；`swift test` 293 个用例全部通过（SwiftyQuickJSTests 44、SwiftyJavaScriptCoreTests 67、SwiftJavaScriptTests 106、SwiftJavaScriptEngineTests 76），`swift format --in-place` 之后重跑仍全部通过；改动的 `.swift` 已 `swift format --in-place`；`rg 'JSEngineSurface|JSSurfaceFactory' Sources Tests Benchmarks` 零命中。未处理：`JSClassDefinition.swift` 的 4 条 “capture of non-Sendable type … in an isolated closure” 警告来自 class 层既有的泛型元类型捕获，本轮未动。
### 3.15.1 S15 收口决策、source breaks 与账本复核

> 3.16 起 `JSEngineSurface` 已删除，用户面类型改由 `JSContext` 锚定；本节保留作 3.15 当时的记录，现状以 §3.16 为准。

**协议分层定稿**

- `JSEngineValueTypes` 只描述共享 arena/registry/转换所需的 `(ContextHandle, ValueHandle, OwnedValueHandle)` 三元组，不承载任何用户面值类型。
- `JSEngineSurface` 钉住 15 个用户面关联类型（Value/CallbackValue/CallbackReturn/Arguments/CallbackArguments/InstantContext/Scope/Context/VirtualMachine/PersistentHandle/PropertyStringKey/PreparedScript/ArrayBuffer/TypedArray/Class）到同一引擎；用户面类型是 public 协议，`JSCValue`/`QJSValue`、`JSCContext`/`QJSContext` 等是引擎具体类型。
- handle 层 requirement 一律无默认实现；值层的 `~Copyable` 默认实现全部写成 `extension … where Self: ~Copyable`，Copyable 的 `JSContext` actor 扩展不需要该约束。

**public 落账原语与 package 缝**

- public 落账原语只有 scope/context 上的 `adoptCreatedHandle`（转移引擎新建引用，track 一次）与 `anchorBorrowedHandle`（claim 后 track 一次）；不存在 public `makeValue(handle:)`。
- `JSSurfaceFactory.makeValue`、`JSScopeWitness.makeValue`、`ScopeCore`/`ScopeFrame`/`ScopeStack`、`JSPersistentHandleRegistry`、`VMThread` 等构造/调度成员是 `package` 内部缝；引擎模块经 public 协议 + 这些 package 缝接线。`JSPersistentHandleIdentity` 是唯一 public 的 registry 身份类型。
- `JSCClassParentDescriptor`/`JSCStaticValue`/`JSCStaticFunction`/`JSCAutoClassDefinition` 保留为 facade 薄别名；`QJSClassDefinition` 与 `QJSVirtualMachine.gc()` 保留为 QJS 专属公开面。

**Source breaks（相对迁移前）**

- 用户面泛型类型 `JSValue<E>`/`JSContext<E>`/`JSCallbackValue<E>`/`JSArguments<E>`/`JSInstantContext<E>`/`JSScope<E>` 等改为同名协议，具体形态由引擎决定（`JSCValue`/`QJSValue` 等）。
- 引擎标记改名 `JavaScriptCoreEngine` → `JSCEngine`、`QuickJSEngine` → `QJSEngine`；handle 全部改为 `JSC*`/`QJS*`，`*Legacy` 类型与 `JSValueConversionEngine` 已删除。
- `JSClass` 现为 core 协议，`JSCClass`/`QJSClass` 是具体类；buffer/class legacy 包装与 `JSCClassLegacy`/`JSCFunctionCallback` 过渡别名不再存在。
- 转换协议最终名为 `JSValueDecodable`/`JSValueEncodable`/`JSValueDecoder`/`JSValueEncoder`/`JSValueCodable`/`JSDefaultConverter`/`JSValueConverter`；临时 `*Surface` 协议名已无声明。
- 值构造入口不再由 public factory 暴露；值视图只能由 scope/context 的落账原语产生。

**lifecycle 账本复核（唯一调用点）**

- persist transfer：`ScopeCoreHandleSurface.persistHandle` 的 `ScopeFrame.takeFirst` + `target.track`。
- anchor：`ScopeCore.anchorBorrowedHandle` 的 `claimOwnedValueHandle` + `track`。
- adopt：`ScopeCore.adoptCreatedHandle` 的 `track`（消费 owned handle）。
- registry claim/root：`JSPersistentHandleRegistry.mintIdentity` 成对调用 `claimOwnedValueHandle` + `rootOwnedValueHandle`。
- settle：`JSPersistentHandleRegistry.settle` 成对 `unrootOwnedValueHandle` + `releaseCreatedHandle`，只由 pump 与 `close()` 调用。

**搜索例外**

- Sources/Tests/Benchmarks 无旧引擎名、`*Legacy`、临时 `*Surface` 协议声明；仅保留 QuickJS C 模块字段名 `CQuickJS*.JSValue`。
- `Tests/SwiftJavaScriptTests/JSEngineCoreTypesTests.swift` 与 `EngineScopeContractTests.swift` 的历史注释仍提到已删除的 `*Legacy` 名称，属于负面样例/迁移历史说明，不是声明或可执行代码。
- `docs/finished/` 保留历史名称；活跃设计文档已更新。

**验证记录（本会话实际运行）**

- `swift build --product PersistentHandleBenchmarks` → `Build complete! (4.16秒)`。
- `swift build --build-tests` → `Build complete! (1.40秒)`。
- `swift test --filter "SurfaceConformanceTests|PackageSeamTests|PersistentHandleContractTests|EnginePreparedInputTests|JSEngineCoreTypesTests|JSValueAutoConvertibleMacroTests|JSValueMacroDiagnosticTests"` → 4 / 20 / 73 / 20 个用例全部通过。
- `swift test --filter "JSCValueCoreTests|QJSValueCoreTests|JSCContextSurfaceTests|QJSContextSurfaceTests|JSCScopeSurfaceTests|QJSScopeSurfaceTests|EngineBufferSurfaceTests|JSCClassValueConvertibleTests|SwiftyQuickJSTests"` → 44 / 24 / 4 个用例全部通过。
- `swift test --filter "JSCClassValueConvertibleTests|JavaScriptCoreBackendDriverTests|EngineRuntimeDriverTests|EngineScopeContractTests|EngineInvocationDriverTests|EnginePropertyDriverTests|EngineTypedArrayDriverTests|EngineValueConversionTests"` → 9 / 48 个用例全部通过。
- 上述过滤运行合计 246 次用例执行（含少量跨过滤重复），均通过；完整 `swift test` 与 `swift format` 按编排约定留给脚本执行，本会话未运行。

范围提醒：handle 相关桥接不在改造范围内；Box 这类共用 util 保留；本轮不管引擎对 core package 的依赖，不要为了公开接口改可见性。

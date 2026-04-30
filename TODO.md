# TODO

本文件只保留仍需执行或仍需约束的事项。已完成的大段历史已按主题归档：

- [Core API、测试与宏完成项](docs/finished/core-api-tests-and-macros.md)
- [引擎迁移完成项](docs/finished/engine-migration.md)
- [清理与基线完成项](docs/finished/cleanup-and-baselines.md)

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
- [x] 修复 JSC callback 返回值 ownership handoff：`callbackRef()` 消费 wrapper 并跳过 `JSValue.deinit -> JSValueUnprotect`，补 Mock deinit/release 计数与跨引擎 callback 回归测试（已完成，`swift test` 通过）

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

- [ ] 新的 QuickJS 引擎实现模块只依赖 `SwiftJavaScript` 的 `public` API；不调用 `package` API，不复制 `SwiftyJavaScriptCore` 私有 helper
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
- [ ] 后续重排线索：`JSEnginePropertyDriver` 混合 string/value/index 属性读写、删除、存在性检查与 propertyNames 枚举；可评估拆分 keyed/indexed property 与 enumeration 能力
- [ ] 后续重排线索：`JSEngineStringDriver` 当前独立于 runtime/context，但 runtime 协议也包含字符串值构造/转换；后续需确认保留独立 string-handle 协议还是合并进 value conversion 边界
- [ ] 后续重排线索：`ClassHandle` 目前挂在 `JSEngineRuntimeDriver`，但 class/host object lifecycle 尚未形成独立能力协议；后续迁移 `JSClass`/host object 时需确认是否拆出 class bridge driver
- [ ] 最后再接 `JSClass` / callback / auto-convertible；到这一步再决定当前剩余 JSC-only 接线哪些真的应继续上收

#### Step Q3：测试策略

- [x] 为 QuickJS 增加最小共享行为测试，优先复用 `SwiftJavaScriptTests` 中已有的 engine-agnostic 覆盖（已扩展 `SwiftJavaScriptEngineTests`）
- [x] 将当前 shared engine tests 从 runtime/property/call 基线扩展到 ArrayBuffer/TypedArray、property attributes、function name/exception callback、Date/Array/instanceof、跨 context 兼容性；每项都同时跑 JSC 与 QuickJS
- [x] 按 `JSEngine` 组合协议来源重排 shared engine tests：`EngineRuntimeDriverTests`、`EnginePropertyDriverTests`、`EngineInvocationDriverTests`、`EngineTypedArrayDriverTests`、`EngineStringDriverTests`、`EngineValueConversionTests` 分别覆盖对应 public API 边界
- [x] 迁移更多 JSC-only public API tests 到 shared engine tests：`JSString`、`JSContext` thin wrapper、runtime/context identity、ArrayBuffer/TypedArray 细分行为、`JSValue` object/type helpers、`defineProperty`、codable/value converter 与 callback return/error coder；本轮迁移未暴露新的 QuickJS/JSC 行为不一致
- [ ] 每发现一处“JSC 迁移得来的边界不符合第二引擎实际”的案例，都在 TODO 里记录并据此调整剩余迁移优先级

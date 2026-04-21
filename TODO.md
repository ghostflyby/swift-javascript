# TODO

## 0. 基线与流程
- [x] 建立并落盘 TODO 清单（按章节与待办条目分列）
- [ ] 每次实现前更新本文件中的进行中条目
- [ ] 每完成一条能力立即打勾并补充简要说明
- [x] 阶段策略确认：迁移阶段保持当前拆分路线，收尾阶段再集中合并类型/扩展与单处 util

## 1. JSContext（C API 对齐）
- [x] 补充 `JSInstantContext` 的 native module 常用入口（值构造、全局对象访问、全局函数安装），并让 `JSContext` 继续做一一对应薄转发（已补 String key 全局 helper、函数安装与基础值构造）
- [x] 将 `JSInstantContext` 作为同步上下文核心，并让 `JSContext` 作为 actor 薄封装一一转发（已完成命名迁移、`evaluateScript` 下沉与 `withGlobalObject` 转发）
- [x] `evaluateScript(_:)`（基于 `JSEvaluateScript`）
- [x] `evaluateScript(_:sourceURL:)`（支持 sourceURL）
- [x] `evaluateScript` 异常透出（返回/抛错策略定稿并实现，当前为 `JSResult`）
- [x] 全局对象快捷访问（`withGlobalObject` / `withIsolatedGlobalObject`）

## 2. JSValue（核心能力）
- [x] 函数调用封装 `call(this:arguments:)`
- [x] 构造调用封装 `construct(arguments:)`
- [x] 方法调用封装 `invokeMethod(_:arguments:)`
- [x] 基础转换：`toBool` / `toDouble` / `toInt32` / `toUInt32`
- [x] 扩展转换：`toString` / `toNumber` / `toObject`
- [x] 类型辅助：`isArray` / `isDate` / `isInstanceOf`
- [x] 属性定义封装：`defineProperty`（基于 `JSObjectSetProperty` + attributes 语义封装）

## 3. 对象与类型化内存（C API）
- [x] ArrayBuffer 封装（创建、长度、字节指针）
- [x] TypedArray 封装（已补类型枚举、创建、长度、byteLength、byteOffset、buffer 访问以及原始字节读写）
- [x] TypedArray 与 `JSValue` 互转辅助（已补 `JSTypedArray(value:)`、`JSValue.isTypedArray`、`JSValue.typedArrayKind` 与 `JSValueEncodable`）

## 4. JSClass 完整接线
- [x] `finalize` 回调接线
- [x] `staticValues` 回调接线
- [x] `staticFunctions` 回调接线
- [x] `getPropertyNames` 回调接线
- [x] `callAsFunction` 回调接线
- [x] `callAsConstructor` 回调接线
- [x] `hasInstance` 回调接线
- [x] `convertToType` 回调接线
- [x] Swift class -> JSClass 导出协议与宏（手动/自动 native conversion 已拆分）

## 5. 测试与稳定性
- [x] 为 `JSContext.evaluateScript` 新增 Swift Testing 用例
- [x] 为 `JSValue` 调用与转换 API 新增 Swift Testing 用例（补充 call/construct/invokeMethod/toObject/type helpers/defineProperty 覆盖）
- [x] 为 TypedArray/ArrayBuffer 新增 Swift Testing 用例（已补 ArrayBuffer 与 TypedArray 的创建、buffer/offset、字节可见性与包装用例）
- [x] 为 JSClass 全部回调路径新增 Swift Testing 用例
- [x] `swift build --build-tests` 持续绿灯
- [x] `swift test` 在本地环境稳定通过（已验证：112/112 通过）
- [x] 迁移部分引擎无关运行时测试为 JSC/QuickJS 多引擎参数化测试（已新增共享 engine test target，覆盖脚本执行、全局 helper、属性访问、调用/构造/方法调用与基础值语义）

## 6. 类型转换体系
- [x] 读写分离协议（`JSValueDecodable` / `JSValueEncodable`）
- [x] 调用点覆盖转换（属性读写与函数参数读取）
- [x] 为后续宏自动实现预留统一转换器模型
- [x] 保留 Callback 协议为底层实现，并由 Actor 版本统一转调（现为 `withInstantContext` 与默认转调扩展）
- [x] 删除 Runtime 转换协议，统一由 `JSValue*` 协议声明 CallbackContext 约束并用扩展补 Actor API

## 7. 宏自动实现（进行中）
- [x] 为 `JSValueCodable` 增加声明式自动实现宏（类似 Codable 自动合成）
- [x] 宏支持类型级 `converter` 或 `decoder/encoder` 替换
- [x] 宏支持成员级单独替换 `decoder/encoder`
- [x] 宏支持 class 类型导出为 `JSClass` 并反映 Swift 继承链
- [x] 调整 enum tagged union 默认模式：`tagKey` 默认改为 `kind`，并在可判定为全 labeled payload 时自动优先扁平展开
- [x] 为 `JSValueAutoSerialization` 增加 final class 值语义自动实现（明确丢失 identity）
- [x] 调整无关联值 RawRepresentable enum 默认语义：按 rawValue 而不是 case 名字合成
- [x] 为 `JSClassAutoConvertible` 增加函数导出标记，支持参数/返回值/错误转换器覆盖

## 8. 多引擎架构迁移（进行中）
- [x] 暂停迁移主线，优先清理无用 helper（按 AGENTS 约束：`JSEngine/JavaScriptCoreBackendDriver` 仅保留引擎必须或低层桥接复用 helper）
- [x] JavaScriptCore backend：内联同类型内仅单次调用的短 helper（test 调用不计），并将测试改为直接覆盖调用方（已内联 `makeRuntime`/`makeContext`/`globalObject`/`privateDataResult`/`makeNumber`/`makeBoolean`/`makeNull`/`makeSymbol`/`isArray`/`isDate`，并将 backend tests 改为经 `makeRuntimeHandle` 与 `makeBorrowedContextHandleFromRuntime` 建立上下文及使用 *ForHandle 调用方）
- [x] JavaScriptCore backend：按注释标记清理 noop/inline helper（已移除 `JavaScriptCoreValueHandle` 的 `rawValue/init(rawValue:)` 与 `valueHandle` 包装，删除 class/typed array/descriptor/equality/undefined 的 backend 透传 helper，typed array 映射改为 `JSTypedArrayKind` 扩展，并内联删除 `JSEngineConversionBridge` 的 JSC 专用转换 noop；调用方、宏模板与 tests 已同步迁移）
- [x] JavaScriptCore backend：继续清理 `JavaScriptCoreBackendDriver.swift` 文件级 helper（已将 callback/class/privateData/valueType/functionClass 等一次性或 facade 专用 helper 回迁到各调用文件顶级，测试改走 *ForHandle/上下文公开入口，Engine 内删除残余 `valueRef(from:)` 依赖并收紧 helper 可见性为 `private`/默认级别）
- [x] JavaScriptCore backend：删除 `JavaScriptCoreValueHandle` 上仅供测试使用的 `type/toDouble/toString` 便捷入口，并统一改回 engine 的 `*ForHandle` 主入口
- [x] Core：删除重复的 `JSDriverResult`，统一改用 `JSResult`，并清理 backend/mock 中仅作枚举重包装的转换 helper
- [x] JavaScriptCore backend：移除 `JavaScriptCoreRawRuntimeStorage`，并让 `JSVirtualMachine/JSContext` 生命周期走 runtime/context handle 的手动引用计数链路
- [x] JavaScriptCore backend：去除 `JavaScriptCoreRawContext` 的 class 包装，改为 handle-first 的值语义上下文载体
- [x] 合并引擎协议职责第一阶段：移除 `JSEngineDriver` 组合协议，改为由实现类型直接 conform `JSEngine + runtime/property/invocation` 子协议，并将通用 handle helper 扩展挂到 `JSEngine`（保持现有 API 与测试稳定）
- [x] 删除未实现的 QuickJS 迁移脚手架：移除 `QuickJSEngine` 与仅其依赖的 `_JSErasedValueHandle`，并将 core tests 的相关覆盖切换到 `MockEngine`
- [x] 将 `JSEngineRuntimeDriver/JSEnginePropertyDriver/JSEngineInvocationDriver` 公开化，并将 `JSEngine` 调整为能力协议组合（补充默认未实现行为与统一结果类型公开可见性）
- [x] 继续收口 `JSClassValueConvertible` callback glue（已将 static value/function callback 的结果/异常包装改复用 backend helper）
- [x] 继续收口 `JSClass` callback glue（已将 static function callback 的名称解析改走 `JSValue` helper，减少 backend 内部 raw context 构造）
- [x] 继续收口 `JSClass` callback glue（已将 callback 输出归一化 helper 统一收口到 backend driver，facade 删除重复包装）
- [x] 继续收口 `JSClassValueConvertible` callback glue（已将 static function 名称解析改走 `JSValue` helper，减少 callback 内部 raw context 构造）
- [x] 收口 `JSClassValueConvertible` 的 facade/raw JSC 直连（已迁 privateData 读取与 class-backed object 创建到 backend handle helper）
- [x] 删除迁移半成品 `JSClassValueConvertible` 协议：将 `jsClassDefinition` 上收至 core `JSClassValueConvertible`，JSC 专用默认实现改挂在其 facade 扩展，`JSClassAutoConvertible` 宏改为仅生成 core 协议 conformance
- [x] 收口 `JSValue` symbol 构造的 facade 直连（已补 `JSEngineDriver`/JSC backend 的 symbol bridge，并切 `JSValue(symbol:in:)` 到 context/handle helper）
- [x] 收口 `JSCodableValueConverter` 的 facade/raw JSC 直连（已将 object/array 构造、属性读写以及 encoder 容器的 primitive/ref 级值构造统一迁到 handle/context helper；当前剩余 raw ref 主要是容器自身的内部存储模型）
- [x] 让 `SwiftyJavaScriptCore` facade 内部开始消费 `SwiftJavaScript` handle（已迁 `JSInstantContext` 基础值/脚本求值、`JSValue` 的基础构造器与 call/construct/invokeMethod/toObject/type helpers/defineProperty，以及 `JSObject` 的 string-key/value-key/index 属性读写删查）
- [x] 将 `SwiftJavaScript` 迁移期 generic handle 接到 `JSEngineDriver`（已补 runtime/context/value/result 的通用桥接构造、脚本求值与基础属性操作，并用 mock driver tests 验证；当前先以 copyable scaffolding 形态打通桥接）
- [x] 扩展 `SwiftJavaScript` generic handle 的公共语义桥接（已补 object/array、call/construct、toObject 与类型辅助，并以 mock driver tests 验证）
- [x] 在 `SwiftJavaScript` 中引入迁移期的引擎无关 concrete handle 类型（已补 `JSRuntimeHandle`/`JSBorrowedContextHandle`/`JSValueHandle`/`JSResultHandle` 骨架与 core tests，作为后续替换最终命名的迁移脚手架）
- [x] 收尾迁移脚手架：删除 `JSBorrowedContextHandle`，测试改为引擎自有 `ContextHandle` 的 `rawContext` 语义
- [x] 抽出 `SwiftJavaScript` target，落地引擎标记、能力描述、宿主描述符与 backend driver 协议（已新增独立 product/target，并由 facade 模块 re-export）
- [x] 为现有 JavaScriptCore 实现补第一版 backend driver，先覆盖基础值、脚本执行、属性访问（已补 `JavaScriptCoreBackendDriver` 与 smoke tests）
- [x] 保持 `SwiftyJavaScriptCore` 现有 public API 与测试面稳定（已验证 `swift test` 67/67 通过）
- [x] 将旧 `JSInstantContext`/`JSContext` 的 phase 1 入口切到 backend driver（已迁移基础值构造、对象/数组构造、脚本执行、全局/对象属性读写删查，覆盖 string-key、value-key 与 index 路径，以及 `JSValue.call`/`construct`/`invokeMethod`/`toObject`/`isArray`/`isDate`/`isInstanceOf`/`defineProperty`；`JSValue` 初始化器、function wiring、`JSClassValueConvertible` 的对象强转/private backing 读写，以及 `JSCodableValueConverter` 的对象/数组创建、属性读写、属性名枚举与数组 index 桥接也已迁移，并清理了旧的 JSValue 私有 helper 遗留；剩余直连主要在 JSClass callback/class-definition 细节与更底层的 JSC 专用实现）
- [x] 将旧 `JSClassDefinition` 的静态成员与构造/析构元数据投影到 `SwiftJavaScript` host descriptor（已补 `hostTypeDescriptor`/member descriptor 投影，当前覆盖静态成员、父类名、构造器与 finalizer 元数据；动态 callback 语义仍待继续迁移）
- [x] 将旧 `JSClassDefinition` 的动态 callback 元数据投影到 `SwiftJavaScript` host descriptor（已补 lifecycle/dynamic property/call/hasInstance/convertToType 绑定字段，并由 `hostTypeDescriptor` 投影）
- [x] 让 JavaScriptCore backend 开始消费 `JSClassDefinition` 投影出的 host descriptor（已由 backend 统一产出 descriptor，并用于 JSClass callback 装配判断与 staticValues/staticFunctions 的名称/属性装配）
- [x] 收口 `JSClass` 动态属性 callback glue（已抽共享 helper 统一上下文恢复、属性名解码与异常/返回值回写，为后续继续下沉到 backend 做准备）
- [x] 收口 `JSClass` 调用类 callback glue（已抽共享 helper 统一 call/construct/hasInstance/convertToType 的上下文恢复、输入值准备与结果/异常桥接）
- [x] 将 `JSClass` 的参数桥接与结果/异常桥接 helper 下沉到 JavaScriptCore backend（`withArguments`、callback return/success/constructor return 已由 backend 提供，`JSClass.swift` 不再维护重复实现）
- [x] 将 `JSClass` 的 callback 输入准备 helper 下沉到 JavaScriptCore backend（dynamic property、function、constructor、hasInstance、convertToType 的上下文恢复与输入值组装已改由 backend 提供）
- [x] 将 `JSClass` 的 static value/static function/propertyNames callback glue 继续下沉到 JavaScriptCore backend（相关输入准备、名称解析与基础桥接已由 backend helper 承担）
- [x] 继续收口 `JSClassValueConvertible` callback glue（已删掉本地 `JSArguments` 包装 helper，统一复用 backend `withArguments`）
- [x] 继续收口 `JSClassValueConvertible` dynamic property callback glue（已将 dynamic get/set 的结果/异常回写改复用 backend helper，并保留 auto storage 的 definition 解析路径）
- [x] 继续收口 `JSClassValueConvertible` dynamic property 输入准备（已抽本地 auto helper，统一 definition/context/key/this 的准备逻辑）
- [x] 继续收口 `JSClassValueConvertible` static value/function 输入准备（已抽本地 auto helper，统一 static member 名称解析与输入值组装）
- [x] 继续收口 `JSClassValueConvertible` auto storage/lifecycle glue（已抽 privateData/storage 解包 helper，统一 initialize/finalize/storage 访问）
- [x] 继续收口 `JSClassValueConvertible` object/context 准备（已抽本地 helper，统一 remembered context 与 this 值组装）
- [x] 继续收口 `JSClassValueConvertible` finalize context 恢复（已抽本地 helper，统一从 stored object context 恢复 this 值）
- [x] 继续收口 `JSClassValueConvertible` callback 默认返回（已抽文件级 helper，统一 optional 结果到 undefined/false 的回退）
- [x] 继续收口 `JSClassValueConvertible` dynamic callback 模板（已抽 dynamic value/bool 专用 helper，减少 autoNativeDefinition 内重复调用样板）
- [x] 继续收口 `JSClassValueConvertible` static callback 模板（已抽 static value/function 专用 helper，统一调用模板与默认回退）
- [x] 继续收口 `JSClassValueConvertible` dynamic callback 具体动作（已抽 get/set/has/delete 文件级 helper，进一步瘦身 autoNativeDefinition）
- [x] 继续收口 `JSClassValueConvertible` static callback 具体动作（已抽 static get/set/function 文件级 helper，进一步瘦身 callback 本体）
- [x] 继续收口 `JSClassValueConvertible` autoNativeDefinition 动态 callback 安装（已抽集中安装 helper，减少函数内重复条件分支）
- [x] 继续收口 `JSClassValueConvertible` autoNativeDefinition 静态成员安装（已抽 staticValues/staticFunctions 安装 helper，进一步精简主函数）
- [x] 收口 `JSClass` callback 内 guard-return 样板（已将 5 处 `guard let value else { return JSValueMakeUndefined }; return value` 与 1 处 bool 版本简化为单行 `?? ` 表达式）
- [x] 收口 `JSCodableValueConverter` 编码容器内 `JSInstantContext(ctx: globalContextRef)` 重复（已统一改为容器级 `instantContext` 属性，显著减少重复上下文构造）
- [x] 继续收口 `JSClass` callback 默认返回（已抽文件级 helper 与双层 optional overload，统一 5 处 undefined fallback 回退）
- [x] 继续收口 `JSClass` callback 布尔默认返回（已抽 `Bool? -> false` helper，统一 didSet/has/delete/hasInstance 回退）
- [x] 继续收口 `JSClass` constructor callback 回退样板（已抽 object fallback helper，统一 `callAsConstructor` 的可选对象返回路径）
- [x] 继续收口 `JSClass` propertyNames callback 回退样板（已抽 `Void?` 回退 helper，统一 getPropertyNames 分支）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 propertyNames 安装 helper，减小主函数体复杂度）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 hasProperty 安装 helper，继续压缩主函数）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 deleteProperty 安装 helper，继续压缩主函数）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 setProperty 安装 helper，继续压缩主函数）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 getProperty 安装 helper，补齐动态属性安装四件套）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 callAsFunction 安装 helper，压缩调用类分支）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 hasInstance 安装 helper，压缩调用类分支）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 callAsConstructor 安装 helper，压缩调用类分支）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装分支（已抽 convertToType 安装 helper，完成调用类分支结构化）
- [x] 继续收口 `JSClass.manualNativeDefinition` 静态成员安装分支（已抽 staticValues 安装 helper，压缩主函数）
- [x] 继续收口 `JSClass.manualNativeDefinition` 静态成员安装分支（已抽 staticFunctions 安装 helper，与 staticValues 对称）
- [x] 继续收口 `JSClass.manualNativeDefinition` 生命周期安装分支（已抽 initialize/finalize 安装 helper）
- [x] 继续收口 `JSClass.manualNativeDefinition` 顶部元数据安装分支（已抽 className 安装 helper）
- [x] 继续收口 `JSClass.manualNativeDefinition` 顶部元数据安装分支（已抽 version/attributes/parentClass 安装 helper）
- [x] 继续收口 `JSClass.manualNativeDefinition` callback 安装顺序分组（已抽 dynamic/callable 分组安装 helper）
- [x] 继续收口 `JSClass.manualNativeDefinition` 主流程分组（已抽 staticMembers/classCallbacks 聚合 helper）
- [x] 继续收口 `JSValueConversion` 数值解码校验样板（已抽 Int32/UInt32 共享整数校验 helper）
- [x] 继续收口 `JSValueConversion` facade/raw JSC 直连（已把 Bool/Double/String 解码改走 backend helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSType` facade/raw JSC 直连（已把 type/is* 与 convertToType 类型映射改走 backend helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSArguments` facade/raw JSC 直连（已通过 backend 暴露 `JavaScriptCoreValueRef` 别名并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSObject` facade/raw JSC 常量直连（已把 property attribute 常量改走 backend helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSCodableValueConverter` facade/raw JSC 类型直连（已统一改用 backend 暴露的 *Ref 别名并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `String` facade/raw JSC 字符串直连（已将 JSString 操作改走 backend helper 与公开别名，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSInstantContext` facade/raw JSC 上下文直连（已改用 backend 暴露的 context/object 别名与 globalObject helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续迁移 `JSInstantContext` 函数创建/安装通用入口到 `SwiftJavaScript`（已下沉 `makeFunction` 与 `installGlobalFunction`，facade 收敛为 JSC 特化上下文辅助）
- [x] 继续收口 `JSArrayBuffer` facade/raw JSC typed-array 直连（已将 ArrayBuffer/TypedArray C API 调用与常量改走 backend helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSValue` facade/raw JSC 值语义直连（已将 unprotect/equality 严格等价判断改走 backend helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSClassValueConvertible` facade/raw JSC callback 类型直连（已将 class/callback/ref 类型与 undefined fallback 改走 backend 别名/helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSClass` facade/raw JSC callback/class-definition 直连（已将 class/ref/callback 类型、class attribute 常量、undefined/class create/retain/release 调用改走 backend 别名/helper，并移除本文件 `import JavaScriptCore`）
- [x] 开始迁移通用类型到 `SwiftJavaScript`（已迁 `JSPropertyAttributes` 基础声明，并在 `JSObject` 侧保留 JSC 常量 extension）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `JSClassAttributes` 基础声明，并在 `JSClass` 侧保留 JSC 常量 extension）
- [x] 继续迁移 `JSClass` 可通用声明到 `SwiftJavaScript`（已抽离 `JSStaticValue` / `JSStaticFunction`，JSC 侧收敛为特化 typealias）
- [x] 继续迁移 `JSClass` 的 host descriptor 投影模板到 `SwiftJavaScript`（已抽离 `hostTypeDescriptor` 组装逻辑为 core helper）
- [x] 继续迁移 `JSClassDefinition` 通用结构到 `SwiftJavaScript`（已新增泛型 `JSClassDefinition`，JSC 侧收敛为特化 typealias，并保留 parent class 名称解析扩展）
- [x] 继续迁移 `JSValue` 的构造与函数包装扩展到 `SwiftJavaScript`（已新增 `JSValue<E>` 通用初始化扩展，JSC 侧删除重复实现并复用 core 版本）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `JSTypedArrayKind` 基础声明，并在 `JSArrayBuffer` 侧保留 typed array type 映射 extension）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `JSType` 基础声明，保留 `JSValue` 类型判断扩展在 JSC facade，并在 backend 侧显式限定 `SwiftJavaScript.JSType` 消除二义性）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `JSValueConversionError`，保留 `JSValueConversion` 协议与实现在 JSC facade）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `TransferableCopy` 基础协议）
- [x] 继续迁移通用测试到 `SwiftJavaScriptTests`（已迁 `TransferableCopyTests`）
- [x] 继续迁移通用测试到 `SwiftJavaScriptTests`（已补已下沉 core 类型语义测试）
- [x] 继续迁移通用测试到 `SwiftJavaScriptTests`（已补 host descriptor/attributes 核心语义测试）
- [x] 继续迁移通用测试到 `SwiftJavaScriptTests`（已补 `JSHostTypeDescriptor` 可选绑定字段语义测试）
- [x] 继续迁移 core 类型到 `SwiftJavaScript`（已完成统一结果类型收口；原 `JSDriverResult` 已删除并并入 `JSResult`）
- [x] 继续迁移 core 类型到 `SwiftJavaScript`（已拆分 `JSEngineDriver` 协议声明为独立文件）
- [x] 继续迁移通用类型离开 JSC 到 SJS（已抽离 `JSResult` 通用容器到 `SwiftJavaScript` 并在 facade 保留 `JSValue` 特化别名）
- [x] 继续迁移通用类型离开 JSC 到 SJS（已迁移 `Box` 与 `SendableBoxUnsafe` 到 `SwiftJavaScript`，并收敛为 `package` 可见性）
- [x] 继续迁移通用实现细节离开 JSC 到 SJS（已迁移 `countTypePack` 到 `SwiftJavaScript` 并保持 `package` 可见性）
- [x] 继续迁移通用测试到 `SwiftJavaScriptTests`（已补 `JSResult`/`Box`/`SendableBoxUnsafe` 核心语义测试）
- [x] 继续迁移通用实现细节离开 JSC 到 SJS（已拆分 `_JSOpaqueHandleStorage` 为独立 core 文件）
- [x] 继续迁移通用实现细节离开 JSC 到 SJS（已拆分 `JSResultHandle` 为独立 core 文件）
- [x] 继续迁移通用实现细节离开 JSC 到 SJS（已拆分 `JSRuntimeHandle` 为独立 core 文件）
- [x] 继续迁移通用实现细节离开 JSC 到 SJS（已拆分 `JSBorrowedContextHandle` 为独立 core 文件）
- [x] 继续迁移通用实现细节离开 JSC 到 SJS（已拆分 `JSValueHandle` 为独立 core 文件）
- [x] 继续迁移通用实现细节离开 JSC 到 SJS（已删除空壳 `JSGenericHandles.swift`）
- [x] 继续迁移 core 描述类型到 SJS（已拆分 `JSHostModuleDescriptor` 与 `JSNativeModule` 为独立文件）
- [x] 继续迁移 core 描述类型到 SJS（按“一次完成”原则，已整体拆分 `JSHostDescriptors.swift` 剩余类型并删除聚合文件）
- [x] 继续迁移 core 类型到 SJS（已按一次完成原则拆分 `JSEngine.swift` 中协议与引擎标记类型）
- [x] 继续迁移 core 实现细节到 SJS（按一次完成原则拆分 `JSEngineDriver.swift` 聚合 extension）
- [x] 继续迁移 core 协议结构到 SJS（按一次完成原则将 `JSEngineDriver` 拆分为 runtime/property/invocation 子协议并保留组合门面）
- [x] 继续收口 facade 结构复杂度（已将 `JSValue` 的 handle/result bridge 从主文件拆分为独立文件，行为保持不变）
- [x] 继续收口 facade 结构复杂度（已将 `JSValue` 的调用/对象互操作 extension 拆分到独立文件，便于后续移动类型位置）
- [x] 中期解耦推进：`JSValue` 内部存储已由直接 `ref/ctx` 切换为 backend raw value 持有（对外 API 与行为保持兼容）
- [x] 中期解耦推进：`JSValue` 主文件已移除 `JavaScriptCore*Ref` 桥接字段/初始化器声明，集中到 bridge 文件承载
- [x] 中期解耦推进：`JSPrivateResult` 已由裸 `JavaScriptCoreValueRef` 切换为 `JavaScriptCoreRawValue`，callback 结果流改走 raw value
- [x] 中期解耦推进：`JSValue` 基础类型判定统一改为显式 `in context` 调用，并移除基于注册表/隐式上下文的判型推断路径（补齐 `JSContext` 与 `JSInstantContext` 显式重载，源码/宏模板/测试已全量迁移）
- [x] 中期解耦推进：`JSValue` 在 `isolated JSContext` 分支下不再直接构造 `JSInstantContext(ctx:)`，统一改走 `withInstantContext` 转发（并修复 `borrowing JSString` 闭包捕获）
- [x] 中期解耦推进：`JSValue(name:callback:in:)` 不再直接依赖 `JavaScriptCoreBackendDriver.makeFunction` 与 `functionClass` 细节，改由 `JSInstantContext.makeFunction` 统一收口
- [x] 中期解耦推进：`JSValueInvocationInterop` 的比较/调用/toObject/类型辅助与 defineProperty 流程不再直接调用 backend，改由 `JSInstantContext` 提供统一收口方法
- [x] 继续迁移 `JSValueInvocationInterop` 到 `SwiftJavaScript` core（已将 call/construct/invokeMethod/toObject/isArray/isDate/isInstanceOf/defineProperty 与参数桥接下沉到通用层，JSC facade 仅保留 equal 语义扩展）
- [x] 继续迁移 `JSClassDefinition` 继承查询 helper 到 `SwiftJavaScript` core（已下沉 inheritanceDepth/exportedDefinitionCount/inheritedStaticValue/inheritedStaticFunction，facade 仅保留 parent definition resolver）
- [x] 继续收口 `JSClass` 继承查询调用点（已移除 facade 全局 wrapper，`JSClassValueConvertible` 与 backend 直接调用 core `JSClassDefinition` helper）
- [x] 迁移边界确认：`JSPropertyAttributes -> JSHostMemberAttributes` 映射保留在 facade（依赖引擎语义位定义，提前下沉会造成标志错位）

### 8.1 InstantContext 收口待办（按“仅底层 bridge 细节收口”原则）

#### P0（优先）
- [x] 收口属性操作三路径（string key / value key / index）到 `JSInstantContext`：统一 get/set/has/delete helper，减少 `driverContextHandle` 与 backend 直连重复（已完成 `JSObject` 三路径调用改走 context helper）
- [x] 收口参数编码与结果桥接工厂：统一 `encodedArguments` 与 handle result -> `JSResult` 流程，消除 call/construct/invokeMethod 重复样板（已新增 `JSInstantContext.encodeArgumentHandles` 与 `bridgeResult` 并替换调用点）
- [x] 收口基础值转换 helper 到 `JSInstantContext`：补齐 toBoolean/toNumber/toString 入口，并让 `JSValueConversion` 改走 context helper

#### P1（次优先）
- [x] 收口基础判型 helper 到 `JSInstantContext`：补齐 isUndefined/isNull/isBoolean/isNumber/isString/isSymbol/isObject/isBigInt 并统一 `JSType` 的 instant 分支入口
- [x] 收口 ArrayBuffer 字节操作 helper 到 `JSInstantContext`：统一 byteLength/bytes 访问与写入路径，减少 `JSArrayBuffer` 中 backend 直连细节（已完成创建/byteLength/bytes 访问改走 context helper）
- [x] 收口 propertyNames 与脚本求值的通用包装：统一名称枚举与 evaluateScript 形态，减少分散重复（已补 `propertyNames(on:)` 并接入转换层；evaluateScript 统一包装已具备）

#### P2（可选）
- [x] 收口 JSClass/JSClassValueConvertible callback 上下文恢复模板到共享 helper（仅收口 privateData/context 恢复等 bridge 样板；已抽 `withRememberedClassObjectValue` / `withStoredClassObjectValue` 并接入 auto callback 路径）
- [ ] 评估对象/数组快速构造 builder 的收口价值，若仅单点使用则不推进

#### 非收口边界（显式约束）
- [ ] 保持 `JSValue`/`JSObject` 的用户语义 API 不下沉（初始化器形态、转换器选择、错误映射等）
- [x] 调整 `JSCodableValueConverter` 的迁移边界（业务序列化语义已迁移到 `SwiftJavaScript` 通用转换层，facade 仅保留 typealias 兼容层）
- [ ] 保持 `JSClassDefinition` 元编程组装不下沉（descriptor 组装与导出语义留在定义层）

### 8.2 里程碑：将 `JSValue` 迁移到 `SwiftJavaScript`

迁移顺序（由低耦合到高耦合）：
- [x] 第 1 步：先将函数回调签名从 `JSValue` 嵌套类型解耦为独立符号（已完成：`JSFunctionCallback` 已独立文件化并替换调用点）
- [x] 第 2 步：将 `JSValue` 的 handle/raw bridge 协议化（已新增 `_JSValueBridgeAdapter` 与 JSC adapter，并接入 `JSValueInvocationInterop` 核心路径）
- [x] 第 3 步：将调用/构造/方法调用核心逻辑下沉到 handle 级 helper（已将参数编码与 call/construct/invokeMethod 编排下沉到 adapter，interop 侧仅保留 facade API 转发）
- [x] 第 4 步：将基础类型判型与转换实现切到 `SwiftJavaScript` 通用入口，facade 仅保留语义包装（已完成：`looselyEquals`/`strictlyEquals`、`JSType`（instant 与 JSContext 统一入口）以及 `Bool/Double/String` 基础转换均已经 adapter 路径）
- [x] 第 5 步：将 `JSValue` 主类型迁移为 `SwiftJavaScript` 的引擎无关实现，JSC 侧保留 typealias/兼容层（已完成：新增 `JSEngineValueStorage<E>` 到 `SwiftJavaScript`，`SwiftyJavaScriptCore` 侧 `_JSValueStorage` 收敛为 typealias + JSC 兼容扩展，`JSValue` 主存储已不再依赖本地 raw-storage 结构）
- [x] 第 6 步：回收兼容层并迁移相关测试到 `SwiftJavaScriptTests`（已补 `JSEngineValueStorage` 两条 core 语义测试；移除 `_JSValueStorage` 的 `fromHandle` shim 与 alias 文件、`JSValue(rawValue:)` 入口、未使用的 `JSResult.from(driverResult:)` / `valueRef(from rawValue:)` / `rawValue(in:)` 兼容桥，将 `JSPrivateResult` 收敛为 core 的 `JSResult<JavaScriptCoreValueRef>`，将全库 `valueHandle(in:)` 调用统一为无参 `valueHandle()`，移除 `JSValue(ref:ctx:)` 默认 `#isolation` 兼容参数，并将 callback 路径替换为 `takeRef()` + `JSResult.toPrivateResult()` 以保持 `consuming` 所有权转移语义；已将 `JSValue` 类型主体下沉并命名为 `SwiftJavaScript.JSValue<E>`，JSC facade 侧删除同名 typealias）

第 6 步收尾约束（context/VM 语义）
- [ ] 约束A：区分 Home Context 与 Operation Context。Home Context 仅负责值生命周期（protect/unprotect、takeRef retain）；Operation Context 仅负责 API 执行。
- [x] 约束B：冲突时不做隐式覆盖。生命周期逻辑永远使用 Home Context，调用/转换/属性访问永远使用显式传入的 Operation Context。（已在 bridge adapter 的 value handle 入口执行校验并保持 API 显式 `in context` 路径）
- [x] 约束C：跨 context 操作前先校验 VM 一致性。不同 VM 直接拒绝；同 VM 的不同 context 允许交换值。（已在 adapter 接入 context-group 一致性 precondition）
- [x] 约束D：补充同 VM 跨 context 值交换测试，固定预期行为，避免后续迁移回退。（已新增 RuntimeTests 同 VM 跨 context 用例）

### 8.3 引擎泛型标记（分阶段）

优先级策略（避免与 8.2 主线互相干扰）：
- [ ] 先完成 8.2 的第 5/6 步，再展开全链路引擎泛型标记改造（避免两类大改叠加导致回归定位困难）

阶段 A：先改 core，不改 facade 用户 API
- [x] 将 `JSInstantContext` 主类型下沉为 `SwiftJavaScript.JSInstantContext<E>`，并删除 JSC facade 的同名 typealias（调用点改为显式 `JSInstantContext<JavaScriptCoreEngine>`）
- [x] 将 `JSInstantContext` 的通用扩展（值构造）下沉到 `JSInstantContext` 同文件（脚本执行仍保留在 facade，待 runtime driver 结果类型统一后再继续下沉）
- [x] 创建 `JSEngineVirtualMachine<E>` 泛型主类型，并在 facade 保留 `JSVirtualMachine` 兼容别名（`Hashable` 按 `RuntimeHandle: Hashable` 条件提供）
- [x] 创建 `JSContext<E>` 泛型主类型，并删除 facade `JSContext` 兼容别名（调用点改为泛型形式）
- [x] 将 `JSResult.from(handleResult:)` 桥接下沉到 `SwiftJavaScript` core（泛型 `JSResult` 扩展），facade 仅保留 JSC 私有结果桥接
- [x] 将 `JSValueConversion.swift` 除 alias 之外的内容迁移到新文件（协议与实现拆分，原文件仅保留类型别名）
- [x] 删除 `JSResultHandle`，handle-result 统一改为 `JSResult<ValueHandle>`（含 driver 协议、JSC backend 与 core tests）
- [x] 迁移 `JSContext` actor：将 JSC 特定上下文创建逻辑下沉到 `JavaScriptCoreContextHandle`，并收缩 actor 存储成员（已在 core 提供 0 参数与 `virtualMachine` 参数初始化器，facade 删除同功能 init；`withIsolatedGlobalObject` 也已下沉到 core）
- [x] 将参数容器主类型更名为 `SwiftJavaScript.JSArguments<E>`，移除 facade `JSArguments` 别名，并保留 `where E == JavaScriptCoreEngine` 的指针桥接初始化
- [x] 将 `JSArrayBuffer` / `JSTypedArray` 下沉到 `SwiftJavaScript` core（新增 `JSArrayBuffer<E>` / `JSTypedArray<E>` 与 typed-array driver 协议；facade 收口为 typealias）
- [x] 将 `JSObject` 属性访问与编解码重载下沉到 `SwiftJavaScript` core（核心改为 `JSValue<E>` 泛型实现，facade 保留 `JSString` 兼容包装）
- [x] 将 `JSString` 协议定义下沉到 `SwiftJavaScript` core（facade 侧保留 `ref` 兼容包装）
- [x] 将 `JSStringManaged` / `JSStringValue` 下沉到 `SwiftJavaScript` core，并在 facade 保留 `ref` 兼容包装（已补 `JSEngineStringDriver` 与 JSC/mock 实现）
- [ ] 在 `SwiftJavaScript` core 层补齐引擎泛型约束，先覆盖 handle/result/driver 协议签名（进行中：conversion 协议去引擎参数化）
- [x] 继续下沉 Context 全局对象/全局属性通用能力到 core（已补 runtime driver 的 global object handle 抽象，并将 JSInstantContext/JSContext 全局对象与全局属性通用方法下沉到 core）
- [x] 继续下沉 `JSValueBridgeAdapter` 的通用调用桥接到 core（call/construct/invokeMethod/toObject/type helpers 已移除 facade 重复实现，跨 VM 校验改为 runtime driver 兼容性 hook）
- [x] 修复 manual ref-count handle 字段的额外 retain 问题（`JSValue`、`JSStringManaged`、`JSStringValue` 的 handle 初始化不再额外 retain，保留复制路径显式 retain）
- [x] 迁移 `JSCodableValueConverter` 到 core（`SwiftJavaScript` 提供通用实现，facade 收敛为 typealias 兼容层）
- [x] 迁移 `JSClassValueConverter` 到 core（新增 `JSClassValueConvertible`，facade `JSClassValueConvertible` 适配并移除重复 converter 定义）
- [x] 迁移 `JSClassValueConvertible` 的 auto storage/container 到 core（已新增 `SwiftJavaScript` 的通用 auto storage 与 class cache registry，facade 收敛为 JSC 特化 typealias 与调用）
- [x] 迁移 `JSClass` object-definition/finalize-counter registry 到 core（新增通用 depth/finalize registry，facade 仅保留 object key 适配）
- [x] 迁移 `JSClass` object-context/class-definition registry 到 core（新增通用 map registry，facade 仅保留 key 计算与桥接调用）

- [x] 迁移 `JSClass` manual native backing 到 core（新增通用 manual backing 存储类型，facade 改为 JSC 特化 typealias）
- [ ] 保留过渡兼容层（typealias/adapter）以确保当前 `SwiftyJavaScriptCore` API 与测试面稳定

阶段 B：按垂直切片迁移，逐段收口
- [x] Slice 1：`JSValue` 调用链（call/construct/invokeMethod）全链路引擎泛型化（已在 core 下沉调用链与参数桥接，JSC 侧仅保留 equal 专有语义）
- [ ] Slice 2：基础判型与基础转换链路泛型化
- [ ] Slice 3：`JSObject` 属性访问链路泛型化
- [ ] Slice 4：`JSClass` callback 输入输出链路泛型化

阶段 C：收尾
- [ ] 删除过渡兼容层与旧路径
- [ ] 在 `SwiftJavaScriptTests` 增加“跨引擎误用应在编译期失败”的测试样例

### 8.4 剩余 JSC -> Core 迁移清单（按步骤）

边界约束：
- [ ] 不迁移 `JSContextRef/JSGlobalContextRef/JSObjectRef/JSClassRef/JSStringRef/JSPropertyNameAccumulatorRef`、`JavaScriptCore.JSStaticValue`、`JavaScriptCore.JSStaticFunction` 本体；这些仍属于 JSC facade/backend 的原始桥接边界
- [ ] 仅迁移这些原始类型之上的引擎无关组装逻辑、结果桥接模板与可复用的定义投影逻辑
- [ ] 不以“搬空 facade”为目标；后续迁移以“core 暴露接口/模板，JSC 保留具体实现”为准
- [ ] 保留在 JSC 的内容包括：raw ref 生命周期、`JavaScriptCore.JSClassDefinition` / `JSStaticValue` / `JSStaticFunction` 字段写入、`JSObject*Callback` 接线、`JSObjectGetPrivate` / `JSObjectSetPrivate` / exception pointer 读写
- [ ] 迁移到 core 的内容包括：definition 组装规则、static member 查找模板、auto storage 状态计算、与具体引擎无关的 callback 前后置模板（已删除冗余 static/definition installation plan，仅保留 callback flags）

Step 1：继续删 facade 薄包装
- [x] 评估并删除 `Sources/SwiftyJavaScriptCore/JSValueResultBridge.swift` 中仅作 core `bridgeHandleResult` 薄封装的入口，调用点直接落到 core helper（已删除未使用的 `JSResult.from(handleResult:)` facade 包装）
- [x] 评估并删除 `Sources/SwiftyJavaScriptCore/JSInstantContext.swift` / `Sources/SwiftyJavaScriptCore/JSContext.swift` 中仅暴露 `globalContextRef` 的兼容扩展；若仍需要 raw context，改集中到 backend-only 桥接面（已删除 `JSInstantContext.globalContextRef`；移除了 facade `JSContext.globalContextRef` 文件，剩余 raw context 访问收口为 JSC backend 内部桥接入口供测试/底层使用）
- [x] 评估 `Sources/SwiftyJavaScriptCore/JSArguments.swift` 的 `pointer + count` 初始化是否仍值得保留在 facade；若只服务 callback glue，则收口到 callback 所在文件附近（已删除该 facade 文件；backend 改为就地构造 `JSArguments`，测试改为局部 helper）
- [x] 收口 `Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreBackendDriver.swift` 中仅服务 callback/typed-array bridge 的 helper；driver 仅保留 core driver 协议要求的方法与直接实现（已将 callback glue、typed-array bridge、property-attributes 和 `JavaScriptCoreStringHandle` 拆到独立 bridge 文件）

Step 2：为剩余值语义 API 决定是否扩 core driver
- [x] 评估 `Sources/SwiftyJavaScriptCore/JSValueBridgeAdapter.swift` / `Sources/SwiftyJavaScriptCore/JSValueInvocationInterop.swift` 的 `looselyEquals/strictlyEquals` 是否提升为 core driver 协议能力；若决定不通用，则明确标注为 JSC-only API（已决定上收到 core driver）
- [x] 若相等性上收到 core，则新增对应 engine driver hook，并删除 facade 中对 `JSValueIsEqual` / `JSValueIsStrictEqual` 的直接调用

Step 3：继续下沉 `JSClass` 的定义组装逻辑
- [x] 先在 core 提炼 `JSClassDefinition` 的“安装计划”接口：明确 metadata / static members / lifecycle / dynamic-property / callable 五组阶段，不直接携带任何 JSC callback 类型（已抽出 metadata / static-members / callback-flags 计划，`JSClass` / auto native definition 改为消费计划）
- [x] 在 core 为 static members 增加可复用的安装规划数据，而不是直接迁移 `JavaScriptCore.JSStaticValue` / `JavaScriptCore.JSStaticFunction` 写入代码（已通过 installation plan 的 static-member 数据承载）
- [x] 在 core 抽出 definition 继承链查找模板，供 `JSClass` 与 `JSClassValueConvertible` 共同消费，避免 facade 重复写 `classDefinition(for: $0.ref)` 闭包（已新增 `JSClassDefinitionLookup`，JSC 收口为单一 resolver 适配点）
- [ ] JSC facade 继续保留 `kJSClassDefinitionEmpty`、`JSClassCreate/Retain/Release`、`JSClassDefinition` 字段赋值和各类 `JSObject*Callback` 接线，只消费 core metadata + callback flags（已删除冗余 static/definition installation plan）
- [ ] 审查 `JSClass.borrow(ctx:)`、`JSClass(ref:)`、registry 与 raw lifecycle 周边是否还能进一步收口为 “JSC handle wrapper + core definition metadata/flags” 结构，避免 facade 同时承载定义模型和 raw class 生命周期

Step 4：继续下沉 `JSClassValueConvertible` 的 auto glue
- [ ] 从 `Sources/SwiftyJavaScriptCore/JSClassValueConvertible.swift` 中继续迁移 auto native definition 的引擎无关组装步骤：auto storage 访问模板、definition 选择策略、callback 前后置模板（进行中：auto storage 的 `usesManagedParent` / `finalizeDepth` / typed instance 模板，以及 backing/storage 的 definition 选择模板已下沉到 core）
- [x] 在 core 提炼“从 definition 解析 static value/function”的名称查找模板，JSC facade 仅负责从 `JSStringRef` / function object 上取出名字再调用模板；static member metadata 已直接消费 definition，不再经 installation plan 中转（`JSClass` / `JSClassValueConvertible` 已改为直接消费 core 的 `inheritedStaticValue/Function` 模板）
- [x] 在 core 提炼 auto-convertible 的 definition 选择与 parent-definition 解析接口，JSC facade 只提供 `JSClassRef -> definition` 的适配闭包（已将 auto backing/storage 的 definition 选择模板下沉到 core，JSC 仅传入 lookup）
- [ ] 将 `JSClassValueConvertible` 中剩余可通用的 callback 前后置模板继续下沉到 core，只保留 `JSObjectInitializeCallback` / `JSObjectFinalizeCallback` / `JSObjectGetPropertyCallback` / `JSObjectSetPropertyCallback` / `JSObjectCallAsFunctionCallback` 等 JSC C callback 接线（进行中：dynamic property 默认语义已下沉到 core；继续收口 static get/function call 的结果包装）
- [ ] 收口 `JSClassValueConvertible` 中仍直接依赖 `JSClass` / `JSPropertyNameAccumulatorRef` 的公开约束，优先改成 core 泛型接口 + facade 特化，而不是继续扩大 facade API 面

Step 4.5：拆分 class definition 的结构与行为
- [x] 引入 engine-agnostic 的 core class definition / static member descriptor，先承载 metadata、parent chain 和 static member 名称/属性
- [x] 引入 core `JSClass<E>` 与 class handle 协议，让引擎绑定的 class 句柄从 `JSClassDefinition` 中分离出来（已新增 `JSClassManualReferenceCountedHandle` / core `JSClass<E>`，并让 JSC facade 收敛为 `JSClass<JavaScriptCoreEngine>` 特化）
- [ ] 让现有 `JSClassDefinition<E, ...>` 导出并逐步消费新的 core definition，而不是继续把 metadata 和行为混在一个类型里（进行中：已把 `JSClassDefinition` 名称收口为完整协议，原纯 metadata struct 更名为 `JSClassDefinitionMetadata`，lookup / auto storage / converter helper 已开始按协议消费；`JSEngineClassDefinition` 暂仍作为默认存储实现，后续需继续收口命名与角色）
- [ ] 后续再把 callbacks 和 engine-bound static member implementations 从 class definition 本体中进一步拆离
- [x] 验证“完整定义协议 + 默认存储实现”模式能否复用于 static member 定义（已为 `JSStaticValue` / `JSStaticFunction` 引入完整定义协议并保持现有 concrete struct 作为默认实现；generic 消费与现有调用面兼容，后续可据此再评估是否上收到 `JSClassDefinition`，但不再继续拆成 descriptor/behavior 双主模型）

Step 5：宏与公开文档去 JSC 硬编码
- [ ] 审查 `Sources/SwiftyJavaScriptCore/JSValueConversionMacros.swift` 中仍直接写死 `JavaScriptCoreEngine` / `JSClass` / `JSPropertyNameAccumulatorRef` 的说明与生成模板，优先改为引用 core converter/protocol 语义
- [ ] 补一轮面向 `SwiftJavaScriptTests` 的迁移测试，把新下沉的 `JSClass` / auto-convertible 组装逻辑优先放到 core 测试覆盖，避免继续只能在 JSC facade tests 中验证
- [ ] 为每一轮“core 接口 + JSC 实现”拆分补对应测试：core 侧测安装计划/解析模板，JSC 侧只测 raw callback wiring 与实际 JavaScriptCore 行为

### 8.5 QuickJS 作为边界验证器（新）

原则：
- [ ] 新的 QuickJS 引擎实现模块只依赖 `SwiftJavaScript` 的 `public` API；不调用 `package` API，不复制 `SwiftyJavaScriptCore` 私有 helper
- [ ] 将后续“是否应继续迁移到 core”的判断切换为：QuickJS 最小桥接是否被迫需要新的 `public` API；若需要，再重构接线边界，而不是继续只按 JSC 形状推断
- [ ] 当 QuickJS 实现受阻时，只允许两类修正：提升真正通用的 `public` core API，或回退不合理抽象；不为 QuickJS 添加第二套私有兼容层

Step Q1：搭建最小 QuickJS 模块
- [x] 新增 QuickJS facade/backend target（建议命名与 `SwiftyJavaScriptCore` 对齐），先只接入 runtime/context/value 基础骨架（已新增 `SwiftyQuickJS` target/product、QuickJS handle 类型与最小 backend driver）
- [x] 先实现最小竖切：`JSVirtualMachine` / `JSContext` / `evaluateScript`（已打通 runtime/context handle、脚本求值、基础值构造/转换，并补最小 QuickJS smoke tests）
- [x] 记录第一批为了 QuickJS 不得不新增或调整的 `public` core API，并回写到本 TODO（已完成一处真实修正：`JSFunctionCallback<E>` 不再强制暴露当前 function object，QuickJS `makeFunction` 已按 `Unmanaged` boxed closure + C trampoline 接线）

Step Q2：逐层验证 public 边界
- [x] 将 `JSEngine` 收敛为能力协议组合别名，并拆分 JSC/QuickJS 各能力 conformance 文件；同步记录后续协议职责重排线索（已验证 `swift build` 与 `swift test` 112/112 通过）
- [x] 将 JSC/QuickJS 各 driver conformance 的具体实现移动到对应 `*Engine*Driver.swift` 文件，保留少量跨能力共享 bridge helper（已验证 `swift build` 与 `swift test` 112/112 通过）
- [x] 整理 engine 协议与 driver/conformance 实现到各 target 的 `Engine/` 子目录，降低源根目录文件数量
- [x] 整理 `SwiftJavaScript` core 内 `JSClass` 与 host descriptor 相关源码到子目录，降低 core 源根目录文件数量
- [ ] 补齐基础值构造、判型与基础转换；如果需要新接口，只提升到 `SwiftJavaScript public`
- [ ] 补齐 object/property 与 call/construct/invoke；继续以第二引擎实现作为接线边界的验真器（进行中：将 `JSValue` 收口为真正负责值句柄生命周期的 noncopyable 壳，并让 `QuickJSValueHandle` 改回普通 struct）
- [ ] 后续重排线索：`JSEngineRuntimeDriver` 同时承担 runtime/context 生命周期、脚本求值、基础值工厂、函数工厂、判型与基础转换；可评估拆出 lifecycle/evaluation/value-factory/value-conversion 协议
- [ ] 后续重排线索：`JSEngineInvocationDriver` 同时承担 call/construct/toObject、Array/Date/instanceof 判定与 equality；可评估将 equality 与对象判型迁到 value/object semantics 协议
- [ ] 后续重排线索：`JSEngineTypedArrayDriver` 同时承担 ArrayBuffer 外部内存、TypedArray 构造、字节视图与类型判定；QuickJS 目前只有部分构造能力，适合按 capability 拆分 ArrayBuffer 与 TypedArray factory/introspection
- [ ] 后续重排线索：`JSEnginePropertyDriver` 混合 string/value/index 属性读写、删除、存在性检查与 propertyNames 枚举；可评估拆分 keyed/indexed property 与 enumeration 能力
- [ ] 后续重排线索：`JSEngineStringDriver` 当前独立于 runtime/context，但 runtime 协议也包含字符串值构造/转换；后续需确认保留独立 string-handle 协议还是合并进 value conversion 边界
- [ ] 后续重排线索：`ClassHandle` 目前挂在 `JSEngineRuntimeDriver`，但 class/host object lifecycle 尚未形成独立能力协议；后续迁移 `JSClass`/host object 时需确认是否拆出 class bridge driver
- [ ] 最后再接 `JSClass` / callback / auto-convertible；到这一步再决定当前剩余 JSC-only 接线哪些真的应继续上收

Step Q3：测试策略
- [ ] 为 QuickJS 增加最小共享行为测试，优先复用 `SwiftJavaScriptTests` 中已有的 engine-agnostic 覆盖
- [ ] 每发现一处“JSC 迁移得来的边界不符合第二引擎实际”的案例，都在 TODO 里记录并据此调整剩余迁移优先级

## 9. JavaScriptCore 导入消除基线（进行中）

### 9.1 当前基线（2026-03-14）
- 当前 `Sources/**/*.swift` 中 `import JavaScriptCore` 总计：`1` 处
- backend 适配层保留导入：`1` 处
	- `Sources/SwiftyJavaScriptCore/Engine/JavaScriptCoreBackendDriver.swift`
- 需在重构中彻底消除导入（目标清单）：`0` 处（已清零）

### 9.2 阶段性指标（消除导入且保持功能）
- [x] 指标A：上述“目标清单”文件中的 `import JavaScriptCore` 数量从 `1` 降到 `0`
- [x] 指标B：每次减少导入后保持 `swift build --build-tests` 通过
- [x] 指标C：每次减少导入后保持 `swift test` 全量通过（当前基线：`91` tests passed）

## 10. 无用 Helper 清理（进行中）
- [x] 清理 `JavaScriptCoreBackendDriver` 中短小一次性 fallback helper（已删除 `callbackBoolOrFalse` / `callbackObjectOrNil` / `callbackDidRun` 并在 `JSClass` 调用点就地内联）
- [x] 清理 `JSClassValueConvertible` 内部同类短 helper（已删除 `autoCallbackValueOrUndefined` / `autoCallbackSucceededOrFalse` 及单处包装型 bool helper，调用点就地内联）
- [x] 清理 `JSClass` / `JSClassValueConvertible` 的纯转发 helper（已删除 `resolveParentDefinition` / `autoClassStorage` / `autoClassDefinition`，调用点改为就地闭包与表达式）
- [x] 清理后执行 `swift build --build-tests` + `swift test` 并按单独 cleanup commit 收口（已验证 96 tests passed）

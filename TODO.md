# TODO

## 0. 基线与流程
- [x] 建立并落盘 TODO 清单（按章节与待办条目分列）
- [ ] 每次实现前更新本文件中的进行中条目
- [ ] 每完成一条能力立即打勾并补充简要说明

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
- [x] `swift test` 在本地环境稳定通过（已验证：73/73 通过）

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
- [x] 继续收口 `JSClassValueConvertible` callback glue（已将 static value/function callback 的结果/异常包装改复用 backend helper）
- [x] 继续收口 `JSClass` callback glue（已将 static function callback 的名称解析改走 `JSValue` helper，减少 backend 内部 raw context 构造）
- [x] 继续收口 `JSClassValueConvertible` callback glue（已将 static function 名称解析改走 `JSValue` helper，减少 callback 内部 raw context 构造）
- [x] 收口 `JSClassValueConvertible` 的 facade/raw JSC 直连（已迁 privateData 读取与 class-backed object 创建到 backend handle helper）
- [x] 收口 `JSValue` symbol 构造的 facade 直连（已补 `_JSEngineDriver`/JSC backend 的 symbol bridge，并切 `JSValue(symbol:in:)` 到 context/handle helper）
- [x] 收口 `JSCodableValueConverter` 的 facade/raw JSC 直连（已将 object/array 构造、属性读写以及 encoder 容器的 primitive/ref 级值构造统一迁到 handle/context helper；当前剩余 raw ref 主要是容器自身的内部存储模型）
- [x] 让 `SwiftyJavaScriptCore` facade 内部开始消费 `SwiftJavaScript` handle（已迁 `JSInstantContext` 基础值/脚本求值、`JSValue` 的基础构造器与 call/construct/invokeMethod/toObject/type helpers/defineProperty，以及 `JSObject` 的 string-key/value-key/index 属性读写删查）
- [x] 将 `SwiftJavaScript` 迁移期 generic handle 接到 `_JSEngineDriver`（已补 runtime/context/value/result 的通用桥接构造、脚本求值与基础属性操作，并用 mock driver tests 验证；当前先以 copyable scaffolding 形态打通桥接）
- [x] 扩展 `SwiftJavaScript` generic handle 的公共语义桥接（已补 object/array、call/construct、toObject 与类型辅助，并以 mock driver tests 验证）
- [x] 在 `SwiftJavaScript` 中引入迁移期的引擎无关 concrete handle 类型（已补 `JSRuntimeHandle`/`JSBorrowedContextHandle`/`JSValueHandle`/`JSResultHandle` 骨架与 core tests，作为后续替换最终命名的迁移脚手架）
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
- [x] 继续收口 `JSArrayBuffer` facade/raw JSC typed-array 直连（已将 ArrayBuffer/TypedArray C API 调用与常量改走 backend helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSValue` facade/raw JSC 值语义直连（已将 unprotect/equality 严格等价判断改走 backend helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSClassValueConvertible` facade/raw JSC callback 类型直连（已将 class/callback/ref 类型与 undefined fallback 改走 backend 别名/helper，并移除本文件 `import JavaScriptCore`）
- [x] 继续收口 `JSClass` facade/raw JSC callback/class-definition 直连（已将 class/ref/callback 类型、class attribute 常量、undefined/class create/retain/release 调用改走 backend 别名/helper，并移除本文件 `import JavaScriptCore`）
- [x] 开始迁移通用类型到 `SwiftJavaScript`（已迁 `JSPropertyAttributes` 基础声明，并在 `JSObject` 侧保留 JSC 常量 extension）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `JSClassAttributes` 基础声明，并在 `JSClass` 侧保留 JSC 常量 extension）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `JSTypedArrayKind` 基础声明，并在 `JSArrayBuffer` 侧保留 typed array type 映射 extension）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `JSType` 基础声明，保留 `JSValue` 类型判断扩展在 JSC facade，并在 backend 侧显式限定 `SwiftJavaScript.JSType` 消除二义性）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `JSValueConversionError`，保留 `JSValueConversion` 协议与实现在 JSC facade）
- [x] 继续迁移通用类型到 `SwiftJavaScript`（已迁 `TransferableCopy` 基础协议）
- [x] 继续迁移通用测试到 `SwiftJavaScriptTests`（已迁 `TransferableCopyTests`）
- [x] 继续迁移通用测试到 `SwiftJavaScriptTests`（已补已下沉 core 类型语义测试）

## 9. JavaScriptCore 导入消除基线（进行中）

### 9.1 当前基线（2026-03-14）
- 当前 `Sources/**/*.swift` 中 `import JavaScriptCore` 总计：`1` 处
- backend 适配层保留导入：`1` 处
	- `Sources/SwiftyJavaScriptCore/JavaScriptCoreBackendDriver.swift`
- 需在重构中彻底消除导入（目标清单）：`0` 处（已清零）

### 9.2 阶段性指标（消除导入且保持功能）
- [x] 指标A：上述“目标清单”文件中的 `import JavaScriptCore` 数量从 `1` 降到 `0`
- [x] 指标B：每次减少导入后保持 `swift build --build-tests` 通过
- [x] 指标C：每次减少导入后保持 `swift test` 全量通过（当前基线：`81` tests passed）


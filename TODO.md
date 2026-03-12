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

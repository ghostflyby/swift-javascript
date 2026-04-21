# Core API、测试与宏完成项

归档自 `TODO.md` 中已经完成的早期 API 对齐、测试、类型转换与宏工作。

## 基线与流程

- [x] 建立并落盘 TODO 清单（按章节与待办条目分列）
- [x] 阶段策略确认：迁移阶段保持当前拆分路线，收尾阶段再集中合并类型/扩展与单处 util

## JSContext（C API 对齐）

- [x] 补充 `JSInstantContext` 的 native module 常用入口（值构造、全局对象访问、全局函数安装），并让 `JSContext` 继续做一一对应薄转发
- [x] 将 `JSInstantContext` 作为同步上下文核心，并让 `JSContext` 作为 actor 薄封装一一转发
- [x] `evaluateScript(_:)`（基于 `JSEvaluateScript`）
- [x] `evaluateScript(_:sourceURL:)`（支持 sourceURL）
- [x] `evaluateScript` 异常透出（返回/抛错策略定稿并实现，当前为 `JSResult`）
- [x] 全局对象快捷访问（`withGlobalObject` / `withIsolatedGlobalObject`）

## JSValue（核心能力）

- [x] 函数调用封装 `call(this:arguments:)`
- [x] 构造调用封装 `construct(arguments:)`
- [x] 方法调用封装 `invokeMethod(_:arguments:)`
- [x] 基础转换：`toBool` / `toDouble` / `toInt32` / `toUInt32`
- [x] 扩展转换：`toString` / `toNumber` / `toObject`
- [x] 类型辅助：`isArray` / `isDate` / `isInstanceOf`
- [x] 属性定义封装：`defineProperty`（基于 `JSObjectSetProperty` + attributes 语义封装）

## 对象与类型化内存（C API）

- [x] ArrayBuffer 封装（创建、长度、字节指针）
- [x] TypedArray 封装（类型枚举、创建、长度、byteLength、byteOffset、buffer 访问以及原始字节读写）
- [x] TypedArray 与 `JSValue` 互转辅助（`JSTypedArray(value:)`、`JSValue.isTypedArray`、`JSValue.typedArrayKind` 与 `JSValueEncodable`）

## JSClass 完整接线

- [x] `finalize` 回调接线
- [x] `staticValues` 回调接线
- [x] `staticFunctions` 回调接线
- [x] `getPropertyNames` 回调接线
- [x] `callAsFunction` 回调接线
- [x] `callAsConstructor` 回调接线
- [x] `hasInstance` 回调接线
- [x] `convertToType` 回调接线
- [x] Swift class -> JSClass 导出协议与宏（手动/自动 native conversion 已拆分）

## 测试与稳定性

- [x] 为 `JSContext.evaluateScript` 新增 Swift Testing 用例
- [x] 为 `JSValue` 调用与转换 API 新增 Swift Testing 用例
- [x] 为 TypedArray/ArrayBuffer 新增 Swift Testing 用例
- [x] 为 JSClass 全部回调路径新增 Swift Testing 用例
- [x] `swift build --build-tests` 持续绿灯
- [x] `swift test` 在本地环境稳定通过
- [x] 迁移部分引擎无关运行时测试为 JSC/QuickJS 多引擎参数化测试

## 类型转换体系

- [x] 读写分离协议（`JSValueDecodable` / `JSValueEncodable`）
- [x] 调用点覆盖转换（属性读写与函数参数读取）
- [x] 为后续宏自动实现预留统一转换器模型
- [x] 保留 Callback 协议为底层实现，并由 Actor 版本统一转调（`withInstantContext` 与默认转调扩展）
- [x] 删除 Runtime 转换协议，统一由 `JSValue*` 协议声明 CallbackContext 约束并用扩展补 Actor API

## 宏自动实现

- [x] 为 `JSValueCodable` 增加声明式自动实现宏
- [x] 宏支持类型级 `converter` 或 `decoder/encoder` 替换
- [x] 宏支持成员级单独替换 `decoder/encoder`
- [x] 宏支持 class 类型导出为 `JSClass` 并反映 Swift 继承链
- [x] 调整 enum tagged union 默认模式：`tagKey` 默认改为 `kind`，并在可判定为全 labeled payload 时自动优先扁平展开
- [x] 为 `JSValueAutoSerialization` 增加 final class 值语义自动实现（明确丢失 identity）
- [x] 调整无关联值 RawRepresentable enum 默认语义：按 rawValue 而不是 case 名字合成
- [x] 为 `JSClassAutoConvertible` 增加函数导出标记，支持参数/返回值/错误转换器覆盖

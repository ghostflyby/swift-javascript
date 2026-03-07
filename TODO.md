# TODO

## 0. 基线与流程
- [x] 建立并落盘 TODO 清单（按章节与待办条目分列）
- [ ] 每次实现前更新本文件中的进行中条目
- [ ] 每完成一条能力立即打勾并补充简要说明

## 1. JSContext（C API 对齐）
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
- [ ] TypedArray 封装（创建、长度、offset、buffer 访问）
- [ ] TypedArray 与 `JSValue` 互转辅助

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
- [ ] 为 TypedArray/ArrayBuffer 新增 Swift Testing 用例（已补 ArrayBuffer，TypedArray 待补）
- [x] 为 JSClass 全部回调路径新增 Swift Testing 用例
- [x] `swift build --build-tests` 持续绿灯
- [x] `swift test` 在本地环境稳定通过（已验证：55/55 通过）

## 6. 类型转换体系
- [x] 读写分离协议（`JSValueDecodable` / `JSValueEncodable`）
- [x] 调用点覆盖转换（属性读写与函数参数读取）
- [x] 为后续宏自动实现预留统一转换器模型
- [x] 保留 Callback 协议为底层实现，并由 Actor 版本统一转调（新增 `withCallbackContext` 与默认转调扩展）
- [x] 删除 Runtime 转换协议，统一由 `JSValue*` 协议声明 CallbackContext 约束并用扩展补 Actor API

## 7. 宏自动实现（进行中）
- [x] 为 `JSValueCodable` 增加声明式自动实现宏（类似 Codable 自动合成）
- [x] 宏支持类型级 `converter` 或 `decoder/encoder` 替换
- [x] 宏支持成员级单独替换 `decoder/encoder`
- [x] 宏支持 class 类型导出为 `JSClass` 并反映 Swift 继承链
- [x] 调整 enum tagged union 默认模式：`tagKey` 默认改为 `kind`，并在可判定为全 labeled payload 时自动优先扁平展开

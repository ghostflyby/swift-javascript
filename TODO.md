# TODO

## 0. 基线与流程
- [x] 建立并落盘 TODO 清单（按章节与待办条目分列）
- [ ] 每次实现前更新本文件中的进行中条目
- [ ] 每完成一条能力立即打勾并补充简要说明

## 1. JSContext（C API 对齐）
- [ ] `evaluateScript(_:)`（基于 `JSEvaluateScript`）
- [ ] `evaluateScript(_:sourceURL:)`（支持 sourceURL）
- [ ] `evaluateScript` 异常透出（返回/抛错策略定稿并实现）
- [ ] 全局对象快捷访问（读写封装，不依赖 ObjC 下标）

## 2. JSValue（核心能力）
- [ ] 函数调用封装 `call(this:arguments:)`
- [ ] 构造调用封装 `construct(arguments:)`
- [ ] 方法调用封装 `invokeMethod(_:arguments:)`
- [ ] 基础转换：`toBool` / `toDouble` / `toInt32` / `toUInt32`
- [ ] 扩展转换：`toString` / `toNumber` / `toObject`
- [ ] 类型辅助：`isArray` / `isDate` / `isInstanceOf`
- [ ] 属性定义封装：`defineProperty`

## 3. 对象与类型化内存（C API）
- [ ] ArrayBuffer 封装（创建、长度、字节指针）
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

## 5. 测试与稳定性
- [ ] 为 `JSContext.evaluateScript` 新增 Swift Testing 用例
- [ ] 为 `JSValue` 调用与转换 API 新增 Swift Testing 用例
- [ ] 为 TypedArray/ArrayBuffer 新增 Swift Testing 用例
- [x] 为 JSClass 全部回调路径新增 Swift Testing 用例
- [ ] `swift build --build-tests` 持续绿灯
- [ ] `swift test` 在本地环境稳定通过（排查并消除 signal 5）

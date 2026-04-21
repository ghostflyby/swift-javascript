# 引擎迁移完成项

归档自 `TODO.md` 中已经完成的多引擎架构迁移、JSC -> Core 迁移与 QuickJS 边界验证工作。

## 早期多引擎架构迁移

- [x] 暂停迁移主线，优先清理无用 helper
- [x] JavaScriptCore backend：内联同类型内仅单次调用的短 helper，并将测试改为直接覆盖调用方
- [x] JavaScriptCore backend：按注释标记清理 noop/inline helper
- [x] JavaScriptCore backend：继续清理 `JavaScriptCoreBackendDriver.swift` 文件级 helper
- [x] JavaScriptCore backend：删除 `JavaScriptCoreValueHandle` 上仅供测试使用的便捷入口
- [x] Core：删除重复的 `JSDriverResult`，统一改用 `JSResult`
- [x] JavaScriptCore backend：移除 `JavaScriptCoreRawRuntimeStorage`，并让 VM/context 生命周期走 runtime/context handle 手动引用计数链路
- [x] JavaScriptCore backend：去除 `JavaScriptCoreRawContext` 的 class 包装，改为 handle-first 的值语义上下文载体
- [x] 合并引擎协议职责第一阶段：移除 `JSEngineDriver` 组合协议
- [x] 删除未实现的 QuickJS 迁移脚手架，并将 core tests 切换到 `MockEngine`
- [x] 将 `JSEngineRuntimeDriver` / `JSEnginePropertyDriver` / `JSEngineInvocationDriver` 公开化，并将 `JSEngine` 调整为能力协议组合

## JSClass 与 callback glue 收口

- [x] 收口 `JSClassValueConvertible` callback glue：结果/异常包装、名称解析、privateData、class-backed object 创建、static/dynamic callback 模板与默认返回等路径已逐步迁移或共享
- [x] 收口 `JSClass` callback glue：动态属性、调用类、static value/static function/propertyNames、默认返回、constructor/propertyNames 回退、callback 安装分支与 metadata/static/lifecycle 分组安装已结构化
- [x] 删除迁移半成品 `JSClassValueConvertible` 协议，将 `jsClassDefinition` 上收到 core `JSClassValueConvertible`
- [x] 将 `JSClass` 的参数桥接、结果/异常桥接、callback 输入准备 helper 下沉到 JavaScriptCore backend
- [x] 迁移 `JSClassDefinition` 继承查询 helper 到 `SwiftJavaScript` core，并移除 facade wrapper
- [x] 迁移边界确认：`JSPropertyAttributes -> JSHostMemberAttributes` 映射保留在 facade

## Facade raw JSC 直连收口

- [x] 收口 `JSValue` symbol 构造、基础构造器、call/construct/invokeMethod/toObject/type helpers/defineProperty 与 equality/unprotect 路径
- [x] 收口 `JSCodableValueConverter` object/array 构造、属性读写、propertyNames、数组 index 桥接与容器上下文构造
- [x] 收口 `JSValueConversion`、`JSType`、`JSArguments`、`JSObject`、`JSCodableValueConverter`、`String`、`JSInstantContext`、`JSArrayBuffer`、`JSClassValueConvertible`、`JSClass` 的 `import JavaScriptCore` 与 raw JSC 常量/类型直连
- [x] 继续迁移 `JSInstantContext` 函数创建/安装通用入口到 `SwiftJavaScript`

## SwiftJavaScript core 类型与测试迁移

- [x] 抽出 `SwiftJavaScript` target，落地引擎标记、能力描述、宿主描述符与 backend driver 协议
- [x] 为 JavaScriptCore 实现补第一版 backend driver，覆盖基础值、脚本执行、属性访问
- [x] 将旧 `JSInstantContext` / `JSContext` phase 1 入口切到 backend driver
- [x] 将 `JSClassDefinition` 的静态成员、构造/析构、动态 callback 元数据投影到 `SwiftJavaScript` host descriptor，并让 JSC backend 消费该投影
- [x] 迁移 `JSPropertyAttributes`、`JSClassAttributes`、`JSStaticValue` / `JSStaticFunction`、`JSClassDefinition`、`JSValue` 初始化扩展、`JSTypedArrayKind`、`JSType`、`JSValueConversionError`、`TransferableCopy`、`JSResult`、`Box`、`SendableBoxUnsafe`、`countTypePack` 等通用类型/实现到 `SwiftJavaScript`
- [x] 拆分 `_JSOpaqueHandleStorage`、`JSResultHandle`、`JSRuntimeHandle`、`JSBorrowedContextHandle`、`JSValueHandle` 等 handle 文件，并删除空壳聚合文件
- [x] 拆分 `JSHostModuleDescriptor` / `JSNativeModule` / `JSHostDescriptors`、`JSEngine` 与 `JSEngineDriver` 聚合文件
- [x] 迁移通用测试到 `SwiftJavaScriptTests`，覆盖 core 类型语义、host descriptor/attributes、`JSResult`、`Box`、`SendableBoxUnsafe` 等

## JSValue 迁移里程碑

- [x] 第 1 步：将函数回调签名从 `JSValue` 嵌套类型解耦为 `JSFunctionCallback`
- [x] 第 2 步：将 `JSValue` 的 handle/raw bridge 协议化
- [x] 第 3 步：将调用/构造/方法调用核心逻辑下沉到 handle 级 helper
- [x] 第 4 步：将基础类型判型与转换实现切到 `SwiftJavaScript` 通用入口
- [x] 第 5 步：将 `JSValue` 主类型迁移为 `SwiftJavaScript` 的引擎无关实现，JSC 侧保留兼容层
- [x] 第 6 步：回收兼容层并迁移相关测试到 `SwiftJavaScriptTests`
- [x] 约束B：冲突时不做隐式覆盖，生命周期使用 Home Context，操作使用显式 Operation Context
- [x] 约束C：跨 context 操作前先校验 VM 一致性
- [x] 约束D：补充同 VM 跨 context 值交换测试

## InstantContext 收口

- [x] 收口属性操作三路径到 `JSInstantContext`
- [x] 收口参数编码与结果桥接工厂
- [x] 收口基础值转换 helper 到 `JSInstantContext`
- [x] 收口基础判型 helper 到 `JSInstantContext`
- [x] 收口 ArrayBuffer 字节操作 helper 到 `JSInstantContext`
- [x] 收口 propertyNames 与脚本求值的通用包装
- [x] 收口 JSClass/JSClassValueConvertible callback 上下文恢复模板到共享 helper
- [x] 调整 `JSCodableValueConverter` 的迁移边界，facade 仅保留 typealias 兼容层

## 引擎泛型标记阶段 A 已完成项

- [x] 将 `JSInstantContext` 主类型下沉为 `SwiftJavaScript.JSInstantContext<E>`
- [x] 将 `JSInstantContext` 的通用扩展下沉到 core
- [x] 创建 `JSEngineVirtualMachine<E>` 泛型主类型，并在 facade 保留 `JSVirtualMachine` 兼容别名
- [x] 创建 `JSContext<E>` 泛型主类型，并删除 facade `JSContext` 兼容别名
- [x] 将 `JSResult.from(handleResult:)` 桥接下沉到 core
- [x] 将 `JSValueConversion.swift` 除 alias 之外的内容迁移到新文件
- [x] 删除 `JSResultHandle`，handle-result 统一改为 `JSResult<ValueHandle>`
- [x] 迁移 `JSContext` actor，并将通用初始化器与 `withIsolatedGlobalObject` 下沉到 core
- [x] 将参数容器主类型更名为 `SwiftJavaScript.JSArguments<E>`
- [x] 将 `JSArrayBuffer` / `JSTypedArray` 下沉到 core
- [x] 将 `JSObject` 属性访问与编解码重载下沉到 core
- [x] 将 `JSString` 协议定义、`JSStringManaged`、`JSStringValue` 下沉到 core
- [x] 下沉 Context 全局对象/全局属性通用能力到 core
- [x] 下沉 `JSValueBridgeAdapter` 的通用调用桥接到 core
- [x] 修复 manual ref-count handle 字段额外 retain 问题
- [x] 迁移 `JSCodableValueConverter`、`JSClassValueConverter`、`JSClassValueConvertible` auto storage/container、JSClass registry 与 manual native backing 到 core

## JSC -> Core 已完成步骤

- [x] Step 1：删除 facade 薄包装，包括 `JSValueResultBridge`、raw context 兼容扩展、`JSArguments` facade 文件与部分 backend helper
- [x] Step 2：将 `looselyEquals` / `strictlyEquals` 上收到 core driver 协议能力
- [x] Step 3：提炼 `JSClassDefinition` metadata / static-members / callback-flags 计划、static member 安装规划数据与继承链查找模板
- [x] Step 4：提炼 static value/function 名称查找模板，以及 auto-convertible definition 选择与 parent-definition 解析接口
- [x] Step 4.5：引入 engine-agnostic core class definition / static member descriptor、core `JSClass<E>` 与 class handle 协议，并验证 static member 定义协议模式

## QuickJS 边界验证已完成项

- [x] 新增 QuickJS facade/backend target
- [x] 实现最小竖切：`JSVirtualMachine` / `JSContext` / `evaluateScript`
- [x] 记录并修正第一批 QuickJS 需要的 `public` core API
- [x] 将 `JSEngine` 收敛为能力协议组合别名，并拆分 JSC/QuickJS 各能力 conformance 文件
- [x] 将 JSC/QuickJS 各 driver conformance 的具体实现移动到对应 `*Engine*Driver.swift` 文件
- [x] 整理 engine 协议与 driver/conformance 实现到各 target 的 `Engine/` 子目录
- [x] 整理 `SwiftJavaScript` core 内 `JSClass` 与 host descriptor 相关源码到子目录

# 多引擎后端架构设计

[English](MULTI_ENGINE_BACKENDS.md) | [简体中文](MULTI_ENGINE_BACKENDS.zh-CN.md)

本文档定义 SwiftyJavaScriptCore 演进到多引擎架构时的基础设计。目标是支持 JavaScriptCore、QuickJS 等多个后端，并保证：

- Swift 宿主代码只编写一次，即可在多个 JS 引擎上运行。
- 各引擎的值和上下文在编译期隔离，避免跨引擎误用。
- 公共 API 稳定，具体引擎差异收敛到后端适配层。

## 设计目标

### 目标

- 提供统一的 Swift API 来创建值、执行脚本、导出宿主函数和宿主模块。
- 支持一个 Swift native module 安装到不同 JS 引擎。
- 让不同引擎的 JSValue、JSContext、JSResult 等类型不能混用。
- 允许不同引擎在能力上有差异，并在 API 中显式表达。

### 非目标

- 不要求所有引擎暴露完全相同的底层能力。
- 不要求不同引擎的 GC、finalizer、Promise job queue 行为完全一致。
- 第一阶段不强行统一 ESM loader、Inspector、Debugger 等高级能力。

## 总体分层

推荐分成四层。

### 1. Core 抽象层

这一层只定义公共语义，不直接依赖 JavaScriptCore 或 QuickJS。

核心职责：

- 定义公共值类型和上下文类型。
- 定义值编解码协议。
- 定义宿主模块和宿主类型描述。
- 定义后端驱动协议。

推荐目标名：

- SwiftJavaScript

### 2. Engine Backend 层

每个引擎单独实现一套后端驱动。

核心职责：

- 管理 runtime/context/value 的底层句柄。
- 实现属性访问、函数调用、脚本执行、异常封送。
- 将宿主模块和宿主类型描述映射到具体引擎能力。

推荐目标名：

- SwiftyJSJavaScriptCore
- SwiftyJSQuickJS

### 3. C Bridge 层

对于 C 库型引擎，需要单独的桥接目标承载头文件、modulemap 和必要的薄封装。

推荐目标名：

- CQuickJS

JavaScriptCore 使用系统框架，一般不需要单独 bridge target。

### 4. Macro 层

宏应只依赖 Core 抽象层，生成引擎无关的宿主描述，而不是直接生成某个引擎专属 glue code。

推荐目标名：

- SwiftyJSMacros

## 类型系统策略

多引擎设计中，最关键的决定是：公共句柄使用带引擎参数的具体类型，而不是把 JSValue、JSContext 本身做成协议。

推荐模型：

```swift
public protocol JSEngine {}

public struct JSRuntime<E: JSEngine>: ~Copyable {}
public struct JSContext<E: JSEngine>: ~Copyable {}
public struct JSBorrowedContext<E: JSEngine>: ~Copyable {}
public struct JSValue<E: JSEngine>: ~Copyable {}
public enum JSResult<E: JSEngine>: ~Copyable {
  case value(JSValue<E>)
  case exception(JSValue<E>)
}
```

这样设计有三个直接收益：

- JSValue<JavaScriptCoreEngine> 无法传给 JSContext<QuickJSEngine>。
- 宿主模块可以对任意引擎泛化实现。
- 公共 API 仍然是具体类型，避免协议 existential 和关联类型扩散到整个用户侧接口。

## 为什么不把 JSValue 做成协议

不推荐如下方向：

- protocol JSValueProtocol
- protocol JSContextProtocol
- protocol JSEngine { associatedtype Value: JSValueProtocol }

原因：

- 协议和关联类型会快速污染整个 API 面。
- 不利于 noncopyable 句柄类型的表达。
- 宏生成和类型擦除会变复杂。
- 许多 API 天然要求返回同一引擎上的其他值，协议图会迅速膨胀。

结论是：

- 值和上下文应当是具体泛型类型。
- 驱动和能力描述应当是协议。

## 唯一后端驱动协议

虽然公共句柄使用泛型具体类型，但底层仍然应该只有一套后端驱动协议。

示意如下：

```swift
public protocol JSEngine {}

internal protocol JSEngineDriver {
  associatedtype Engine: JSEngine
  associatedtype RawRuntime
  associatedtype RawContext
  associatedtype RawValue

  static func makeRuntime() -> RawRuntime
  static func makeContext(in runtime: borrowing RawRuntime) -> RawContext

  static func evaluateScript(
    _ script: String,
    in context: borrowing RawContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> DriverResult<RawValue>

  static func makeString(_ value: String, in context: borrowing RawContext) -> RawValue
  static func makeNumber(_ value: Double, in context: borrowing RawContext) -> RawValue
  static func makeBoolean(_ value: Bool, in context: borrowing RawContext) -> RawValue
  static func makeNull(in context: borrowing RawContext) -> RawValue
  static func makeUndefined(in context: borrowing RawContext) -> RawValue

  static func getProperty(
    _ key: String,
    on object: borrowing RawValue,
    in context: borrowing RawContext
  ) -> DriverResult<RawValue>

  static func setProperty(
    _ key: String,
    on object: borrowing RawValue,
    to value: borrowing RawValue,
    in context: borrowing RawContext,
    attributes: JSPropertyAttributes
  ) -> DriverResult<Void>
}
```

公共层的 JSContext<E>、JSValue<E> 内部持有对应 driver 的 raw handle。

## 引擎标签类型

不同引擎应有自己的标签类型。

```swift
public enum JavaScriptCoreEngine: JSEngine {}
public enum QuickJSEngine: JSEngine {}
```

这样值隔离是编译期完成的，而不是依靠运行时判断。

## 宿主模块模型

跨引擎复用的核心不应是 JSClass，而应是宿主模块和宿主类型描述。

推荐宿主模块协议：

```swift
public protocol JSNativeModule {
  static var moduleName: String { get }

  static func install<E: JSEngine>(
    into context: borrowing JSBorrowedContext<E>
  ) throws
}
```

如果模块只依赖公共 API，就可以在多个后端上复用。

对于更声明式的表达，建议定义描述符：

```swift
public struct JSHostModuleDescriptor: Sendable {
  public var name: String
  public var functions: [JSHostFunctionDescriptor]
  public var constants: [JSHostConstantDescriptor]
  public var types: [JSHostTypeDescriptor]
}
```

后端负责把这类描述符映射到具体引擎的函数、对象和原型机制。

## 宿主类型模型

现有 JSClassDefinition 更接近某个具体引擎的宿主类模型。多引擎下应将其提升为引擎无关的描述符。

推荐名称：

- JSHostTypeDescriptor

建议包含：

- 名称
- 构造器
- 实例方法
- 静态方法
- 实例属性
- 生命周期回调
- 继承关系
- Swift 对象存储策略

示意：

```swift
public struct JSHostTypeDescriptor: Sendable {
  public var name: String
  public var constructor: JSHostConstructorDescriptor?
  public var methods: [JSHostFunctionDescriptor]
  public var staticMethods: [JSHostFunctionDescriptor]
  public var properties: [JSHostPropertyDescriptor]
  public var parent: String?
  public var finalizer: (@Sendable () -> Void)?
}
```

映射方式：

- JavaScriptCore 后端把它编译成 JSClass、staticFunctions、private storage。
- QuickJS 后端把它编译成 JSClassID、prototype object、opaque pointer。

## 能力差异模型

不要假设所有引擎能力一致。应当显式声明能力。

推荐能力描述：

```swift
public struct JSEngineCapabilities: Sendable {
  public var supportsBigInt: Bool
  public var supportsSymbol: Bool
  public var supportsExternalArrayBuffer: Bool
  public var supportsHostObjects: Bool
  public var supportsESModules: Bool
  public var supportsPromiseJobQueueControl: Bool
}
```

每个后端对外暴露其能力集。公共 API 面对能力差异时有两种处理方式：

- 返回明确错误
- 提供条件化 API

不要为了接口统一而伪造不存在的引擎能力。

## 生命周期与内存模型

不同引擎的值生命周期管理不同，但公共层应保证统一的最小语义。

统一原则：

- JSValue<E> 是某个引擎值的 Swift 句柄。
- JSValue<E> 与所属 context/runtime 绑定。
- 不承诺不同引擎拥有相同 GC 时机。
- 不承诺 finalizer 的触发顺序和时间点一致。

应当统一的只有这些：

- 值在所属引擎内有效。
- 值不能跨引擎使用。
- 值不能脱离上下文生命周期不受控地悬挂。

## 上下文模型

建议保留当前项目已经形成的双层上下文语义：

- actor 持有的稳定上下文
- 同步调用窗口内的 borrowed context

推荐接口轮廓：

```swift
public actor JSContext<E: JSEngine> {
  public func withBorrowedContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSBorrowedContext<E>) throws(Failure) -> R
  ) throws(Failure) -> R
}
```

这套模型适合继续沿用，因为：

- 它能明确区分长期所有权和短时借用。
- 它能适配 JSCore 和 QuickJS 两种常见嵌入模型。
- 它能和 noncopyable 值句柄自然配合。

## 公共值编解码协议

现有项目的值转换协议语义是可复用的，但需要泛型化到引擎参数。

推荐轮廓：

```swift
public protocol JSValueDecodable: ~Copyable {
  static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSBorrowedContext<E>
  ) throws(JSValueConversionError) -> Self
}

public protocol JSValueEncodable: ~Copyable {
  func tryEncode<E: JSEngine>(
    in context: borrowing JSBorrowedContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
}
```

这样模块和转换器对引擎保持泛化，但仍然会在同一类型参数 E 下工作。

## 哪些约束必须静态化

下列约束值得通过泛型在编译期强制保证：

- 不同引擎的 JSValue 不能混用。
- 不同引擎的 JSContext 不能混用。
- 不同引擎的 JSResult、JSArguments、JSException 不能混用。

下列约束不值得强行放进类型系统：

- 同一引擎不同 runtime 的完全隔离。
- 同一引擎不同 context 的完全静态隔离。
- GC 与 finalizer 的确定性一致。

原因是前者成本低且收益高，后者会显著放大 API 复杂度。

## 包结构建议

建议最终结构如下：

```text
Package
|- Sources/
|  |- SwiftJavaScript/
|  |- SwiftyJSJavaScriptCore/
|  |- SwiftyJSQuickJS/
|  |- CQuickJS/
|  `- SwiftyJSMacros/
`- Tests/
  |- SwiftJavaScriptTests/
   |- SwiftyJSJavaScriptCoreTests/
   `- SwiftyJSQuickJSTests/
```

建议产品：

- SwiftJavaScript
- SwiftyJSJavaScriptCore
- SwiftyJSQuickJS

如果需要兼容现有命名，可让 SwiftyJavaScriptCore 暂时作为 facade product，内部 re-export JavaScriptCore backend。

## 迁移策略

推荐按四步走，避免一次性重写。

### 第一步：抽 Core 层

- 把公共错误类型、属性类型、宿主描述符、转换协议迁入 SwiftJavaScript。
- 把现有 JSContext 和 JSValue 的公共语义从 JavaScriptCore 依赖中剥离。

### 第二步：重写当前 JavaScriptCore 后端

- 用新的后端驱动协议承载现有 JSCore 实现。
- 保持当前对外 API 尽量不变，只把底层落点迁移到 backend target。

### 第三步：让宏改为生成引擎无关描述符

- 宏不直接生成 JSClass 绑定代码。
- 宏生成 JSHostModuleDescriptor 和 JSHostTypeDescriptor 之类的描述。

### 第四步：接入 QuickJS

- 新增 CQuickJS bridge target。
- 新增 SwiftyJSQuickJS backend target。
- 优先完成脚本执行、基础值、属性访问、宿主函数导出。
- 最后再补宿主类型、ArrayBuffer、模块加载等高级能力。

## 第一阶段建议能力范围

为了降低多引擎接入成本，第一阶段建议只统一这些能力：

- 创建基本值
- 获取和设置属性
- 调用函数和构造函数
- 执行脚本
- 导出全局函数
- 安装宿主模块
- 值编解码

以下能力可以第二阶段再处理：

- TypedArray 和外部内存
- Promise job queue 控制
- ESM loader
- Inspector / Debugger
- 引擎私有优化 API

## 决策总结

推荐采用以下组合：

- 用一个唯一的后端驱动协议统一所有引擎实现。
- 用 JSValue<E>、JSContext<E> 这类具体泛型句柄表达公共 API。
- 不把 JSValue 和 JSContext 本身设计成协议。
- 把跨引擎可复用能力建立在宿主模块描述和宿主类型描述之上。
- 把跨引擎误用限制在编译期完成，而不是依赖运行时检查。

这能同时满足三个目标：

- 类型安全
- 公共 API 可维护
- 后端适配层边界清晰

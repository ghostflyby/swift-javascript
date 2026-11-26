# 多引擎后端架构设计

[English](MULTI_ENGINE_BACKENDS.md) | [简体中文](MULTI_ENGINE_BACKENDS.zh-CN.md)

本文档定义 SwiftyJavaScriptCore 的多引擎架构。目标是支持 JavaScriptCore、QuickJS 等多个后端，并保证：

- Swift 宿主代码只编写一次，即可在多个 JS 引擎上运行。
- 各引擎的值和上下文在编译期隔离，避免跨引擎误用。
- 公共 API 稳定，具体引擎差异收敛到后端适配层。

> **实现状态（2026-11，§3.17）。** 迁移已完成，包含 dehandle 收口。core 公开以
> `JSContext` 为锚点的 `JS*` 协议；JavaScriptCore/QuickJS 分别提供具体
> `JSC*`/`QJS*` 类型。public 协议不再暴露任何引擎 handle 类型或 handle 级
> 成员：handle 与 context driver 协议均为 package 内部实现，
> `JSPersistentHandle` 是唯一 public 的 handle 命名家族（绑定身份，不是引擎
> 句柄）。下文保留的 `JSValue<E>` 等泛型句柄描述仅作设计历史；当前契约以
> [类型系统策略](#类型系统策略) 与
> [持久 handle 设计](PERSISTENT_HANDLE_DESIGN.md) 为准。迁移之外还有一个
> 后续项：QuickJS 仍使用 package 缝（`TODO.md` §1.5）；这是可见性决策，
> 不是未完成的类型迁移。

## 设计目标

### 目标

- 提供统一的 Swift API 来创建值、执行脚本、导出宿主函数和宿主模块。
- 支持一个 Swift native module 安装到不同 JS 引擎。
- 让 `JSCValue`/`QJSValue`、`JSCContext`/`QJSContext` 等具体类型及其结果不能跨引擎混用。
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

当前目标名：

- SwiftyJavaScriptCore
- SwiftyQuickJS

### 3. C Bridge 层

对于 C 库型引擎，需要单独的桥接目标承载头文件、modulemap 和必要的薄封装。

当前依赖：

- CQuickJS（通过 `Swift-CQuickJS`）

JavaScriptCore 使用系统框架，不需要单独 bridge target。

### 4. Macro 层

宏只依赖 Core 抽象层，生成 JavaScriptCore 后端使用的具体 `JSC*` facade 类型和描述符。

当前目标名：

- SwiftyJavaScriptCoreMacrosPlugin

## 类型系统策略

当前实现采用“public 协议 + 引擎具体类型”。协议定义共享语义；`JSContext`
是锚点：它为一个引擎的每个用户面类型命名，并把它们之间的关系各陈述一次。

```swift
public protocol JSValue: ~Copyable {
  associatedtype Context: JSContext
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext

  func type() -> JSType
  /// Copyable 的值级调用 token；只在紧接着的同步调用内有效。
  func asCallArgument() -> Context.CallArgument
  // 属性/调用/转换操作收 `in context: borrowing InstantContext`，
  // 返回 `JSResult<Context.Value>` ...
}

public struct JSCValue: JSValue, ~Copyable { /* JavaScriptCore */ }
public struct QJSValue: JSValue, ~Copyable { /* QuickJS */ }

public protocol JSContext: Actor, Hashable {
  associatedtype Value: JSValue & ~Copyable
  where Value.Context == Self, Value.InstantContext == InstantContext
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext.Context == Self, InstantContext.Value == Value
  associatedtype CallArgument: JSCallArgument
  associatedtype Class: JSClass
  where Class.Context == Self
  // scope、工厂、持久 handle、data ...
}

public actor JSCContext: JSContext { /* JavaScriptCore */ }
public actor QJSContext: JSContext { /* QuickJS */ }
```

成员协议不陈述任何关系：各自声明所属的 context（`Context`），并只把它用到的
非 handle 成员类型别名过去（`Value == Context.Value`、
`InstantContext == Context.InstantContext` ……）。所有等式都在 `JSContext`
里，方向是从 context 指向它的成员。`ContextHandle`/`ValueHandle` 等 handle
关联已不在 public 协议上。

public 面不出现任何引擎 handle。具体值视图在 package 内部保存 borrowed handle
与 context handle；调用实参走 `JSValue`/`JSCallbackValue` 上 `asCallArgument()`
产出的 Copyable 值级 `Context.CallArgument` token（只在源 arena 存活且用于紧
接着的同步调用时有效）。`JSPersistentHandle` 是刻意的例外：它是绑定身份，不是引擎句柄。

引擎隔离由 context 的 same-type 约束表达（`JSCContext.Value == JSCValue`、
`QJSContext.Value == QJSValue` 以及其余关联），不是运行时检查。
用户面的 `JSValue` 不是 existential：`C.Value` 总是指向本引擎的具体
类型，因此 `JSCValue` 不可能进入 `QJSContext`。

直接收益：

- 宿主代码可以泛型化到 `C: JSContext`，同时始终使用同一引擎的值。
- 每个引擎直接在自己的 value/context/scope 类型上实现操作，不必把所有调用
  绕回引擎标记的静态方法。
- 跨引擎误用在编译期失败。

单向约束给泛型代码留下一条规则：涉及值时以 context 为根，窗口类型用
`C.InstantContext`/`C.Scope`。裸窗口类型（`S: JSInstantContext`）只知道
自己属于某个 `S.Context`，无法证明自己就是该 context 的那个窗口，所以
`S.Value` 的操作（在 `S.Value.InstantContext` 里寻址）不接受 `S`。窗口
自身的操作（工厂、global 访问、脚本）在裸 `S` 上可用。把窗口反向钉回
context 可以补上这一缺口，但会让类型检查不收敛（Swift 6.4.2）。

## 为什么 JSValue 仍是协议

早期草案把“协议 + 关联类型”视为反模式，提出具体泛型句柄
（`JSValue<E>`）。迁移在 noncopyable 关联类型与 same-type 约束可用后重新
评估了这一取舍。最终保留 `JSValue`/`JSContext` 协议，因为值的具体形态确实
由引擎决定；同时给协议图一个唯一的枢纽，防止它失控：

- `JSContext` 在一次 conformance 中为十五个用户面类型命名并固定它们的
  关系，形成单一枢纽，而不是把逐类型的协议互相钉死。
- scope 与 value view 携带 `Context` 并把它的类型别名过来；same-type 别名
  阻止跨引擎混用。
- 宏直接生成具体的 `JSC*` surface，不额外增加抽象层。
- 每个引擎模块内 package 级别的 handle 缝（`JSEngineValueTypes`、context driver 协议与引擎
  handle）刻意窄于用户面，不作为用户值抽象暴露；core 内没有 handle 声明。

## 驱动协议

原先的单一后端驱动已拆分，且全部保持在 package 内部；它们不出现在
public 协议面上：

- context 寻址的操作位于 `JSContextRuntimeDriver`、
  `JSContextPropertyDriver`、`JSContextInvocationDriver`、
  `JSContextTypedArrayDriver`、`JSContextPreparedScriptDriver`，由 package 的
  `JSCContextHandle`/`QJSContextHandle` 实现。
- 生命周期与能力描述留在 public 引擎标记（`JSCEngine`/`QJSEngine`）；其
  `JSEngine*` driver conformance 是 package。class 桥
  （`JSEngineClassBridgeDriver`）是独立的 public 值级协议
  （`makeClass`/`makeHostObject`/`hostObjectPrivateData`），由引擎标记遵循。
- core 的共享 arena/registry 以 context handle 为键，只看得到它的
  `JSContextRuntimeDriver` 能力（`ValueHandle`/`OwnedValueHandle`/
  `InstantContext`）。落账原语（`adoptCreatedHandle`、
  `anchorBorrowedHandle`、`adoptCallbackHandle`）是引擎 scope/context 上的
  package 方法；core 从不把已落账的 handle 变成 public 值视图。

示意：

```swift
package protocol JSContextRuntimeDriver: JSContextManualReferenceCountedHandle {
  associatedtype InstantContext: JSInstantContext & ~Copyable
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle.Context == Self
  associatedtype OwnedValueHandle: JSOwnedValueManualReferenceCountedHandle
  where OwnedValueHandle.Context == Self, OwnedValueHandle.Borrowed == ValueHandle
  func makeStringValueHandle(_ value: String) -> OwnedValueHandle?
  // ...
}
```

public 的 `JSCContext`/`QJSContext` actor 把各自句柄保留为 package 内部实现，
只暴露值级协议操作。

## 引擎标签类型

每个引擎有自己的标签类型，承载 runtime 生命周期与能力。引擎的用户面类型
由它的 context 固定，而不是由标签类型固定：

```swift
public enum JSCEngine: Sendable { /* runtime 生命周期、能力 */ }
public enum QJSEngine: Sendable { /* runtime 生命周期、能力 */ }

public actor JSCContext: JSContext { /* JSCValue, JSCInstantContext, ... */ }
public actor QJSContext: JSContext { /* QJSValue, QJSInstantContext, ... */ }
```

引擎标记上的 handle 别名（`ContextHandle`、`ValueHandle`、
`OwnedValueHandle`、`RuntimeHandle`、`ClassHandle`、
`PropertyStringKeyHandle`、`PreparedScriptHandle`）都是
`package typealias`，只用于满足 package driver 协议的 witness。这样值隔离是
编译期完成的，而不是依靠运行时判断。

## 宿主模块模型

跨引擎复用的核心是宿主模块及其描述符，而不是某个引擎的 class 包装。

当前宿主模块协议：

```swift
public protocol JSNativeModule: Sendable {
  static var moduleName: String { get }
  static var descriptor: JSHostModuleDescriptor { get }
}
```

模块描述函数、常量和类型；各后端把描述符映射到自己的函数/对象/原型机制。
只依赖 public surface 的模块可以安装到两个引擎。

更声明式的形式：

```swift
public struct JSHostModuleDescriptor: Sendable {
  public var name: String
  public var functions: [JSHostFunctionDescriptor]
  public var constants: [JSHostConstantDescriptor]
  public var types: [JSHostTypeDescriptor]
}
```

## 宿主类型模型

core 的 `JSClassDefinition` 已引擎无关，并按引擎的 class 桥
（`E: JSEngineClassBridgeDriver`，它为自己的 class 声明所属的 context）
参数化。它是两个后端共享的描述；引擎 facade 只保留
薄别名（`JSCAutoClassDefinition`、`QJSClassDefinition`）。

包含：

- 名称
- 构造器
- 实例方法
- 静态方法
- 实例属性
- 生命周期回调
- 继承关系
- Swift 对象存储策略

映射方式：

- JavaScriptCore 后端把它编译成 `JSClass`、static functions、private storage。
- QuickJS 后端把它编译成 `JSClassID`、prototype object、opaque pointer。

## 能力差异模型

不要假设所有引擎能力一致。能力在引擎标记上显式声明。

当前能力描述：

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

不同引擎的值生命周期管理不同，但公共层保证统一的最小语义。

统一原则：

- 用户面值（`JSCValue`/`QJSValue`）是绑定到引擎 context 的非拥有本地视图。
- scope arena 拥有引擎引用；销毁视图不触发 release。
- `JSPersistentHandle` 只是身份，跨隔离域保活一份 rooted 引擎引用。
- 不承诺不同引擎拥有相同 GC 时机或 finalizer 顺序。

应当统一的只有这些：

- 值在所属引擎和 context 内有效。
- 具体值不能跨引擎使用。
- 值不能脱离 scope/context 生命周期不受控地悬挂。

## 上下文模型

项目使用 actor 持有的 context 加同步 scope 窗口：

- actor 持有的稳定上下文（`JSCContext`/`QJSContext`）
- 同步调用中的 `JSInstantContext` 窗口
- 在 context 隔离域内打开/排空的手动 `JSScope`

当前轮廓：

```swift
public protocol JSContext: Actor, Hashable {
  associatedtype Value: JSValue & ~Copyable
  where Value.Context == Self
  func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing InstantContext) throws(Failure) -> R
  ) throws(Failure) -> R
  func makeScope() -> Scope
}

public actor JSCContext: JSContext { /* ... */ }
public actor QJSContext: JSContext { /* ... */ }
```

这套模型适合继续沿用，因为：

- 它能明确区分长期所有权和短时借用。
- 它能适配 JSCore 和 QuickJS 两种常见嵌入模型。
- 它能和 noncopyable scope 类型及 scope arena 的引用所有权自然配合。

## 公共值编解码协议

转换对 value/scope 类型泛型，而不是对单一引擎标记泛型。

当前轮廓：

```swift
public protocol JSValueDecodable: ~Copyable {
  init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  )
}

public protocol JSValueEncodable: ~Copyable {
  func tryEncodeSurface<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
}
```

`JSDefaultConverter`、`JSValueDecoder`、`JSValueEncoder` 以及
`JSValueConverter`/`JSValueCodable` 别名建立在这两个协议上。解码以 scope
窗口为单根：值始终是窗口自己的 `C.Value`，因此转换器不可能把某个引擎的值视图
和另一个引擎的 scope 混用。抛错形式（`tryDecode`/`tryEncodeSurface`）是带有
默认转发实现的协议要求；非抛错入口（`init`/`toSurfaceValue`）仍是协议要求。

## 哪些约束必须静态化

下列约束由 surface 协议在编译期保证：

- 不同引擎的值不能混用。
- 不同引擎的 context 不能混用。
- 不同引擎的 `JSResult`、`JSArguments` 与回调载体不能混用。

下列约束不强行放进类型系统：

- 同一引擎不同 runtime 的完全隔离。
- 同一引擎不同 context 的完全静态隔离。
- GC 与 finalizer 的确定性一致。

原因是前者成本低且收益高，后者会显著放大 API 复杂度。

## 包结构

当前结构：

```text
Package
|- Sources/
|  |- SwiftJavaScript/
|  |- SwiftyJavaScriptCore/
|  |- SwiftyQuickJS/
|  |- SwiftyJavaScriptCoreMacrosPlugin/
|  `- (CQuickJS 经 Swift-CQuickJS 依赖)
`- Tests/
  |- SwiftJavaScriptTests/
  |- SwiftJavaScriptEngineTests/
  |- SwiftyJavaScriptCoreTests/
  `- SwiftyQuickJSTests/
```

产品：

- SwiftJavaScript
- SwiftyJavaScriptCore
- SwiftyQuickJS

## 迁移策略

四阶段计划已执行完成：

### 第一步：抽 Core 层

已完成：公共错误、属性类型、宿主描述符、转换协议以及 handle/scope 基础设施
位于 `SwiftJavaScript`。

### 第二步：重写当前 JavaScriptCore 后端

已完成：`JSCEngine`、`JSCValue`/`JSCContext` 等 public `JSC*` 类型实现 core
协议；`JSCContextHandle` 与其余 `*Handle` 类型是 package 桥接内部实现。
`SwiftyJavaScriptCore` 保留为 facade 产品，只留 JSC 薄别名与 raw C 桥接。

### 第三步：让宏生成具体 facade

已完成：`@JSValueAutoSerialization` 与 `@JSClassAutoConvertible` 生成 `JSC*`
surface 与描述符，不再生成 legacy 泛型包装。

### 第四步：接入 QuickJS

已完成：`QJSEngine`、`QJS*` 家族（其 handle 是 package 内部实现）、
`QJSValue`/`QJSContext`、class 与 buffer 支持、`QJSVirtualMachine.gc()` 已落地，
并由共享引擎测试目标覆盖。

## 第一阶段能力范围

第一阶段统一了这些能力：

- 创建基本值
- 获取和设置属性
- 调用函数和构造函数
- 执行脚本
- 导出全局函数
- 安装宿主模块
- 值编解码

以下能力当时后置：

- Promise job queue 控制
- ESM loader
- Inspector / Debugger
- 引擎私有优化 API

TypedArray 和外部内存在后续切片中已实现。

## 决策总结

当前采用的组合：

- 以 `JSContext` 为唯一锚点：为十五个用户面类型命名，并把它们的关系各陈述一次。
- 公共 API 使用 `JS*` 协议 + 具体 `JSC*`/`QJS*` 类型，public 面没有 handle
  关联或 handle 级成员。
- `JSEngineValueTypes`、context driver 协议与全部 `*Handle` 只作为各引擎模块内
  package 底层缝，不作为用户值抽象；core 不再声明它们；`JSPersistentHandle` 是唯一
  保留的 public handle 命名家族。
- 把跨引擎可复用能力建立在宿主模块描述和宿主类型描述之上。
- 把跨引擎误用限制在编译期完成，而不是依赖运行时检查。

这能同时满足三个目标：

- 类型安全
- 公共 API 可维护
- 后端适配层边界清晰

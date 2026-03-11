# Multi-Engine Backend Architecture

[English](MULTI_ENGINE_BACKENDS.md) | [简体中文](MULTI_ENGINE_BACKENDS.zh-CN.md)

This document defines the baseline architecture for evolving SwiftyJavaScriptCore into a multi-engine system. The goal is to support multiple backends such as JavaScriptCore and QuickJS while ensuring the following:

- Swift host code is written once and can run on multiple JavaScript engines.
- Values and contexts from different engines are isolated at compile time to prevent cross-engine misuse.
- The public API remains stable, while engine-specific differences are contained within backend adapters.

## Design Goals

### Goals

- Provide a unified Swift API for creating values, evaluating scripts, and exporting host functions and modules.
- Allow a single Swift native module to be installed into different JavaScript engines.
- Ensure types such as JSValue, JSContext, and JSResult from different engines cannot be mixed.
- Allow engines to differ in capabilities, and make those differences explicit in the API.

### Non-Goals

- Not all engines are required to expose exactly the same low-level capabilities.
- Different engines are not required to have identical GC, finalizer, or Promise job queue behavior.
- The first phase does not attempt to unify advanced features such as ESM loaders, inspectors, or debuggers.

## Layering

The recommended design has four layers.

### 1. Core Abstraction Layer

This layer defines shared semantics and does not directly depend on JavaScriptCore or QuickJS.

Responsibilities:

- Define public value and context types.
- Define value encoding and decoding protocols.
- Define host module and host type descriptors.
- Define the backend driver protocol.

Recommended target name:

- SwiftyJSCore

### 2. Engine Backend Layer

Each engine implements its own backend driver.

Responsibilities:

- Manage low-level runtime, context, and value handles.
- Implement property access, function calls, script evaluation, and exception bridging.
- Map host modules and host type descriptors onto engine-specific primitives.

Recommended target names:

- SwiftyJSJavaScriptCore
- SwiftyJSQuickJS

### 3. C Bridge Layer

For C-based engines, a separate bridge target should own headers, modulemaps, and minimal thin wrappers.

Recommended target name:

- CQuickJS

JavaScriptCore is provided as a system framework and usually does not need a dedicated bridge target.

### 4. Macro Layer

Macros should depend only on the Core abstraction layer. They should generate engine-agnostic host descriptions instead of engine-specific glue code.

Recommended target name:

- SwiftyJSMacros

## Type System Strategy

The most important decision in a multi-engine design is to use concrete public handle types parameterized by engine, rather than turning JSValue and JSContext themselves into protocols.

Recommended model:

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

This provides three immediate benefits:

- JSValue<JavaScriptCoreEngine> cannot be passed into JSContext<QuickJSEngine>.
- Host modules can be implemented generically over any engine.
- The public API still uses concrete types, avoiding existential and associated-type leakage across the entire surface area.

## Why JSValue Should Not Be a Protocol

The following approach is not recommended:

- protocol JSValueProtocol
- protocol JSContextProtocol
- protocol JSEngine { associatedtype Value: JSValueProtocol }

Reasons:

- Protocols and associated types quickly spread through the entire API surface.
- They are a poor fit for noncopyable handle types.
- Macro generation and type erasure become more complex.
- Many APIs naturally return other values from the same engine, which makes the protocol graph grow rapidly.

The conclusion is:

- Values and contexts should be concrete generic types.
- Drivers and capability descriptions should be protocols.

## A Single Backend Driver Protocol

Even though the public handle types are concrete generic types, the implementation should still use a single backend driver protocol.

Illustrative shape:

```swift
public protocol JSEngine {}

internal protocol _JSEngineDriver {
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

The public JSContext<E> and JSValue<E> types internally hold raw handles owned by the matching driver.

## Engine Marker Types

Each engine should have its own marker type.

```swift
public enum JavaScriptCoreEngine: JSEngine {}
public enum QuickJSEngine: JSEngine {}
```

This makes engine isolation a compile-time property instead of a runtime check.

## Host Module Model

The center of cross-engine reuse should not be JSClass. It should be host modules and host type descriptors.

Recommended host module protocol:

```swift
public protocol JSNativeModule {
  static var moduleName: String { get }

  static func install<E: JSEngine>(
    into context: borrowing JSBorrowedContext<E>
  ) throws
}
```

If a module depends only on the public API, it can be reused across multiple backends.

For a more declarative representation, define a descriptor:

```swift
public struct JSHostModuleDescriptor: Sendable {
  public var name: String
  public var functions: [JSHostFunctionDescriptor]
  public var constants: [JSHostConstantDescriptor]
  public var types: [JSHostTypeDescriptor]
}
```

Each backend maps these descriptors onto its own function, object, and prototype mechanisms.

## Host Type Model

The current JSClassDefinition is much closer to one engine's host class model. In a multi-engine design, it should be promoted into an engine-agnostic descriptor.

Recommended name:

- JSHostTypeDescriptor

Suggested contents:

- Name
- Constructor
- Instance methods
- Static methods
- Instance properties
- Lifecycle callbacks
- Inheritance
- Swift object storage policy

Illustrative shape:

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

Mapping strategy:

- The JavaScriptCore backend compiles it into JSClass, staticFunctions, and private storage.
- The QuickJS backend compiles it into JSClassID, a prototype object, and an opaque pointer.

## Capability Model

Do not assume all engines have identical capabilities. Capabilities should be declared explicitly.

Recommended capability description:

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

Each backend exposes its capability set. The public API should respond to differences in one of two ways:

- Return an explicit error.
- Provide conditional API entry points.

Do not invent engine features that do not exist just to make the API look uniform.

## Lifetime and Memory Model

Different engines manage value lifetimes differently, but the public layer should define a common minimum semantic contract.

Unified rules:

- JSValue<E> is a Swift handle for a value owned by a specific engine.
- JSValue<E> is tied to its originating context or runtime.
- The API does not promise identical GC timing across engines.
- The API does not promise identical finalizer order or timing across engines.

Only the following should be guaranteed:

- A value is valid within its owning engine.
- A value cannot be used across engines.
- A value cannot outlive its context lifetime in an uncontrolled way.

## Context Model

The project's current two-level context model should be preserved:

- A stable actor-owned context
- A borrowed context used within a synchronous call window

Recommended outline:

```swift
public actor JSContext<E: JSEngine> {
  public func withBorrowedContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSBorrowedContext<E>) throws(Failure) -> R
  ) throws(Failure) -> R
}
```

This model remains a good fit because:

- It cleanly separates long-lived ownership from short-lived borrowing.
- It works well for both JSCore and QuickJS embedding models.
- It naturally matches noncopyable value handles.

## Public Value Conversion Protocols

The existing conversion protocol semantics are reusable, but should be generalized over the engine type parameter.

Recommended outline:

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

This keeps modules and converters generic over the engine while ensuring they still operate under a single engine type parameter E.

## Constraints That Should Be Static

The following constraints are worth enforcing at compile time through generics:

- JSValue from different engines cannot be mixed.
- JSContext from different engines cannot be mixed.
- JSResult, JSArguments, and JSException from different engines cannot be mixed.

The following constraints are not worth forcing into the type system:

- Full static isolation between different runtimes of the same engine.
- Full static isolation between different contexts of the same engine.
- Deterministic consistency of GC and finalizer behavior.

The first set has high safety value at low complexity. The second set adds disproportionate API complexity.

## Package Structure

The recommended final structure is:

```text
Package
|- Sources/
|  |- SwiftyJSCore/
|  |- SwiftyJSJavaScriptCore/
|  |- SwiftyJSQuickJS/
|  |- CQuickJS/
|  `- SwiftyJSMacros/
`- Tests/
   |- SwiftyJSCoreTests/
   |- SwiftyJSJavaScriptCoreTests/
   `- SwiftyJSQuickJSTests/
```

Recommended products:

- SwiftyJSCore
- SwiftyJSJavaScriptCore
- SwiftyJSQuickJS

If compatibility with the current naming is needed, SwiftyJavaScriptCore can temporarily remain as a facade product that re-exports the JavaScriptCore backend.

## Migration Strategy

The recommended migration path has four phases, to avoid a full rewrite.

### Phase 1: Extract the Core Layer

- Move public error types, property types, host descriptors, and conversion protocols into SwiftyJSCore.
- Separate the public semantics of JSContext and JSValue from direct JavaScriptCore dependencies.

### Phase 2: Rebuild the Existing JavaScriptCore Backend

- Use the new backend driver protocol to carry the current JSCore implementation.
- Keep the external API as stable as possible while moving the implementation into a backend target.

### Phase 3: Make Macros Generate Engine-Agnostic Descriptors

- Macros should no longer emit JSClass-specific binding code directly.
- They should generate descriptions such as JSHostModuleDescriptor and JSHostTypeDescriptor.

### Phase 4: Add QuickJS

- Add a CQuickJS bridge target.
- Add a SwiftyJSQuickJS backend target.
- Start with script evaluation, basic values, property access, and host function exports.
- Leave host types, ArrayBuffer, module loading, and other advanced capabilities for later.

## Recommended First-Phase Feature Scope

To reduce the cost of multi-engine adoption, the first phase should unify only these capabilities:

- Creating primitive values
- Getting and setting properties
- Calling functions and constructors
- Evaluating scripts
- Exporting global functions
- Installing host modules
- Encoding and decoding values

The following can be deferred to a second phase:

- TypedArray and external memory
- Promise job queue control
- ESM loader
- Inspector and debugger support
- Engine-specific optimization APIs

## Decision Summary

The recommended combination is:

- Use a single backend driver protocol to unify all engine implementations.
- Use concrete generic handles such as JSValue<E> and JSContext<E> as the public API.
- Do not make JSValue or JSContext themselves into protocols.
- Base cross-engine reuse on host module descriptors and host type descriptors.
- Enforce cross-engine misuse constraints at compile time rather than through runtime checks.

This simultaneously gives you:

- Type safety
- A maintainable public API
- Clear backend boundaries
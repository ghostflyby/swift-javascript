# Multi-Engine Backend Architecture

[English](MULTI_ENGINE_BACKENDS.md) | [简体中文](MULTI_ENGINE_BACKENDS.zh-CN.md)

This document defines the multi-engine architecture of SwiftyJavaScriptCore. The goal is to support multiple backends such as JavaScriptCore and QuickJS while ensuring the following:

- Swift host code is written once and can run on multiple JavaScript engines.
- Values and contexts from different engines are isolated at compile time to prevent cross-engine misuse.
- The public API remains stable, while engine-specific differences are contained within backend adapters.

> **Implementation status (2026-11, §3.16).** The migration is complete. Core
> exposes public `JS*` protocols anchored on `JSContext`; JavaScriptCore and
> QuickJS provide concrete `JSC*`/`QJS*` types. Older sections below that
> described generic handles such as `JSValue<E>` are retained as design
> history only; the current contract is the protocol + concrete-type model in
> [Type System Strategy](#type-system-strategy) and
> [Persistent handle design](PERSISTENT_HANDLE_DESIGN.md). One follow-up
> remains outside this migration: QuickJS still reaches package seams
> (`TODO.md` §1.5), which is a visibility decision, not an unfinished type
> migration.

## Design Goals

### Goals

- Provide a unified Swift API for creating values, evaluating scripts, and exporting host functions and modules.
- Allow a single Swift native module to be installed into different JavaScript engines.
- Ensure concrete types such as `JSCValue`/`QJSValue`, `JSCContext`/`QJSContext`, and their results cannot be mixed across engines.
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

- SwiftJavaScript

### 2. Engine Backend Layer

Each engine implements its own backend driver.

Responsibilities:

- Manage low-level runtime, context, and value handles.
- Implement property access, function calls, script evaluation, and exception bridging.
- Map host modules and host type descriptors onto engine-specific primitives.

Current target names:

- SwiftyJavaScriptCore
- SwiftyQuickJS

### 3. C Bridge Layer

For C-based engines, a separate bridge target should own headers, modulemaps, and minimal thin wrappers.

Current dependency:

- CQuickJS (through `Swift-CQuickJS`)

JavaScriptCore is provided as a system framework and does not have a dedicated bridge target.

### 4. Macro Layer

Macros depend only on the Core abstraction layer. They generate the concrete `JSC*` facade types and descriptors used by the JavaScriptCore backend.

Current target name:

- SwiftyJavaScriptCoreMacrosPlugin

## Type System Strategy

The implemented design pairs public protocols with engine-specific concrete
types. The protocols define the shared semantics; `JSContext` is the anchor
that names every user-facing type of an engine and states each relationship
between them exactly once.

```swift
public protocol JSValue: ~Copyable {
  associatedtype Context: JSContext
  associatedtype ContextHandle: JSContextRuntimeDriver & JSContextInvocationDriver
  where ContextHandle == Context.ContextHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle == Context.ValueHandle
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext
  borrowing func borrowHandle() -> ValueHandle
  // property/call/conversion operations ...
}

public struct JSCValue: JSValue, ~Copyable { /* JavaScriptCore */ }
public struct QJSValue: JSValue, ~Copyable { /* QuickJS */ }

public protocol JSContext: Actor, Hashable {
  associatedtype ContextHandle: JSScopeContextHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle == ContextHandle.ValueHandle
  associatedtype Value: JSValue & ~Copyable
  where Value.Context == Self, Value.ValueHandle == ValueHandle
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext.Context == Self, InstantContext.Value == Value
  // scopes, factories, persistent handles, data ...
}

public actor JSCContext: JSContext { /* JavaScriptCore */ }
public actor QJSContext: JSContext { /* QuickJS */ }
```

The member protocols state no relationships of their own: each names the
context it belongs to (`Context`) and aliases the member types it uses
(`ValueHandle == Context.ValueHandle`, `Value == Context.Value`, ...). Every
equality lives in `JSContext` and points from the context to its members.

Engine isolation is expressed through the context's same-type constraints
(`JSCContext.Value == JSCValue`, `QJSContext.Value == QJSValue`, and the other
associations), not through runtime checks. A user-facing `JSValue` is not an
existential: `C.Value` always resolves to the engine's concrete type, so
`JSCValue` cannot enter `QJSContext`.

Benefits:

- Host code can be generic over `C: JSContext` and still use one engine's
  values consistently.
- Each engine implements operations directly on its own value, context, and
  scope types instead of routing every call through a generic engine marker.
- Cross-engine misuse fails at compile time.

One rule for generic code follows from the one-directional constraints: take
the context as the root whenever values are involved, and use
`C.InstantContext`/`C.Scope` as the window types. A bare window type
(`S: JSInstantContext`) only knows that it belongs to *some* `S.Context`; it
cannot show that it is that context's own window, so the operations of
`S.Value` — addressed in `S.Value.InstantContext` — do not accept an `S`. The
window's own operations (factories, global access, scripts) do work on a bare
`S`. Pinning the window back onto its context would close that gap, but makes
the type checker fail to terminate (Swift 6.4.2).

## Why the Public Protocol Is Still Engine-Pinned

The earlier draft treated protocols and associated types as an anti-pattern and
proposed concrete generic handles (`JSValue<E>`). The migration revisited that
tradeoff after noncopyable associated types and same-type constraints became
available. The final design keeps `JSValue`/`JSContext` as protocols because the
concrete shape genuinely differs per engine, but prevents an open-ended
protocol graph by giving it exactly one hub:

- `JSContext` names all fifteen user-facing types and fixes their
  relationships in one conformance, so the graph has one hub rather than
  per-type protocols pinned onto each other.
- Scopes and value views carry their `Context` and alias its types; their
  same-type aliases keep values from crossing engines.
- Macros generate the concrete `JSC*` surface, not an additional abstraction.
- The handle-only seam (`JSEngineValueTypes`) is deliberately narrower than the
  user surface; it is not exposed as a user-facing value abstraction.

## Driver Protocols

The original single backend driver was decomposed during migration:

- Context-addressed operations live on `JSContextRuntimeDriver`,
  `JSContextPropertyDriver`, `JSContextInvocationDriver`,
  `JSContextTypedArrayDriver`, and `JSContextPreparedScriptDriver`,
  implemented by `JSCContextHandle` and `QJSContextHandle`.
- Lifecycle and capability descriptors stay on the engine marker
  (`JSCEngine` / `QJSEngine`); the class bridge (`JSEngineClassBridgeDriver`)
  is built on it.
- Core's shared arena and registry are keyed on the context handle and see
  only its `JSContextRuntimeDriver` capabilities (`ValueHandle`,
  `OwnedValueHandle`, `InstantContext`). They never construct a value view:
  wrapping a tracked handle in the engine's view is the ledger primitive of
  the engine's scope or context.

Illustrative shape:

```swift
public protocol JSContextRuntimeDriver: JSContextManualReferenceCountedHandle {
  associatedtype InstantContext: JSInstantContext & ~Copyable
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle.Context == Self
  associatedtype OwnedValueHandle: JSOwnedValueManualReferenceCountedHandle
  where OwnedValueHandle.Context == Self, OwnedValueHandle.Borrowed == ValueHandle
  func makeStringValueHandle(_ value: String) -> OwnedValueHandle?
  // ...
}
```

The public `JSCContext`/`QJSContext` actors own their handles and forward to the
context driver; they do not expose raw engine types.

## Engine Marker Types

Each engine has its own marker type for runtime lifecycle and capabilities.
The user-facing types of an engine are fixed by its context, not by the marker:

```swift
public enum JSCEngine: Sendable { /* runtime lifecycle, capabilities */ }
public enum QJSEngine: Sendable { /* runtime lifecycle, capabilities */ }

public actor JSCContext: JSContext { /* JSCValue, JSCInstantContext, ... */ }
public actor QJSContext: JSContext { /* QJSValue, QJSInstantContext, ... */ }
```

This makes engine isolation a compile-time property instead of a runtime check.

## Host Module Model

The center of cross-engine reuse is host modules and their descriptors, not a
single engine's class wrapper.

Current host module protocol:

```swift
public protocol JSNativeModule: Sendable {
  static var moduleName: String { get }
  static var descriptor: JSHostModuleDescriptor { get }
}
```

A module describes its functions, constants, and types; each backend maps the
descriptor onto its own function/object/prototype mechanism. Modules that use
only the public surface can be installed into both engines.

For a more declarative representation:

```swift
public struct JSHostModuleDescriptor: Sendable {
  public var name: String
  public var functions: [JSHostFunctionDescriptor]
  public var constants: [JSHostConstantDescriptor]
  public var types: [JSHostTypeDescriptor]
}
```

## Host Type Model

Core `JSClassDefinition` is engine-agnostic and parameterized by the engine's
class bridge (`E: JSEngineClassBridgeDriver`), which names the context its
classes live in. It is the shared description consumed by both
backends; the engine-specific facade names are thin aliases
(`JSCAutoClassDefinition`, `QJSClassDefinition`).

Suggested contents:

- Name
- Constructor
- Instance methods
- Static methods
- Instance properties
- Lifecycle callbacks
- Inheritance
- Swift object storage policy

Mapping strategy:

- The JavaScriptCore backend compiles it into `JSClass`, static functions, and private storage.
- The QuickJS backend compiles it into `JSClassID`, a prototype object, and an opaque pointer.

## Capability Model

Do not assume all engines have identical capabilities. Capabilities are declared explicitly on the engine marker.

Current capability description:

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

Each backend exposes its capability set. The public API responds to differences in one of two ways:

- Return an explicit error.
- Provide conditional API entry points.

Do not invent engine features that do not exist just to make the API look uniform.

## Lifetime and Memory Model

Different engines manage value lifetimes differently, but the public layer defines a common minimum semantic contract.

Unified rules:

- A user-facing value (`JSCValue`, `QJSValue`) is a non-owning local view scoped to an engine context.
- The scope arena owns the engine reference; dropping a view performs no release.
- `JSPersistentHandle` is identity only and keeps one rooted engine reference alive across isolation domains.
- The API does not promise identical GC timing or finalizer order across engines.

Only the following are guaranteed:

- A value is valid within its owning engine and context.
- A concrete value cannot be used across engines.
- A value cannot outlive its scope/context lifetime in an uncontrolled way.

## Context Model

The project uses an actor-owned context with synchronous scope windows:

- A stable actor-owned context (`JSCContext` / `QJSContext`)
- A `JSInstantContext` window used within a synchronous call
- A manual `JSScope` opened and drained inside the context isolation

Current outline:

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

This model remains a good fit because:

- It cleanly separates long-lived ownership from short-lived borrowing.
- It works well for both JSCore and QuickJS embedding models.
- It naturally matches noncopyable scope types and handle-level ownership.

## Public Value Conversion Protocols

Conversion stays generic over the value and scope types, not over a single
engine marker.

Current outline:

```swift
public protocol JSValueDecodable: ~Copyable {
  static func tryDecode<V: JSValue & ~Copyable, C: JSInstantContext & ~Copyable>(
    _ value: borrowing V,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Self where V.Engine == C.Engine
}

public protocol JSValueEncodable: ~Copyable {
  func tryEncodeSurface<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
}
```

`JSDefaultConverter`, `JSValueDecoder`, `JSValueEncoder`, and the
`JSValueConverter`/`JSValueCodable` aliases build on these two protocols. The
same-type constraint `V.Engine == C.Engine` keeps a converter from mixing an
engine value with another engine's scope.

## Constraints That Should Be Static

The following constraints are enforced at compile time through the surface protocols:

- Values from different engines cannot be mixed.
- Contexts from different engines cannot be mixed.
- `JSResult`, `JSArguments`, and callback carriers from different engines cannot be mixed.

The following constraints are not forced into the type system:

- Full static isolation between different runtimes of the same engine.
- Full static isolation between different contexts of the same engine.
- Deterministic consistency of GC and finalizer behavior.

The first set has high safety value at low complexity. The second set adds disproportionate API complexity.

## Package Structure

The current structure is:

```text
Package
|- Sources/
|  |- SwiftJavaScript/
|  |- SwiftyJavaScriptCore/
|  |- SwiftyQuickJS/
|  |- SwiftyJavaScriptCoreMacrosPlugin/
|  `- (CQuickJS via the Swift-CQuickJS dependency)
`- Tests/
  |- SwiftJavaScriptTests/
  |- SwiftJavaScriptEngineTests/
  |- SwiftyJavaScriptCoreTests/
  `- SwiftyQuickJSTests/
```

Products:

- SwiftJavaScript
- SwiftyJavaScriptCore
- SwiftyQuickJS

## Migration Strategy

The four-phase plan was executed:

### Phase 1: Extract the Core Layer

Completed: public errors, property types, host descriptors, conversion
protocols, and handle/scope infrastructure live in `SwiftJavaScript`.

### Phase 2: Rebuild the Existing JavaScriptCore Backend

Completed: `JSCEngine`, `JSCContextHandle`, and the `JSCValue`/`JSCContext`
family implement the core protocols; `SwiftyJavaScriptCore` remains the facade
product and keeps only thin JSC-specific aliases and raw C bridging.

### Phase 3: Make Macros Generate the Concrete Facade

Completed: `@JSValueAutoSerialization` and `@JSClassAutoConvertible` generate
the `JSC*` surface types and descriptors instead of legacy generic wrappers.

### Phase 4: Add QuickJS

Completed: `QJSEngine`, the `QJS*` handles, `QJSValue`/`QJSContext`, class and
buffer support, and `QJSVirtualMachine.gc()` are implemented and covered by the
shared engine test targets.

## Recommended First-Phase Feature Scope

The first phase unified these capabilities:

- Creating primitive values
- Getting and setting properties
- Calling functions and constructors
- Evaluating scripts
- Exporting global functions
- Installing host modules
- Encoding and decoding values

The following remained deferred:

- Promise job queue control
- ESM loader
- Inspector and debugger support
- Engine-specific optimization APIs

TypedArray and external memory were subsequently implemented as well.

## Decision Summary

The implemented combination is:

- Use `JSContext` as the single anchor that names all fifteen user-facing types and states their relationships once.
- Use public `JS*` protocols with concrete `JSC*`/`QJS*` types.
- Keep `JSEngineValueTypes` as a handle-only low-level seam, not a user-facing value abstraction.
- Base cross-engine reuse on host module descriptors and host type descriptors.
- Enforce cross-engine misuse constraints at compile time rather than through runtime checks.

This gives:

- Type safety
- A maintainable public API
- Clear backend boundaries
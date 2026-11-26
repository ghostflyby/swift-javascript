import SwiftyJavaScriptCore
import SwiftyQuickJS

@testable import SwiftJavaScript

enum ScriptEngine: String, CaseIterable, CustomStringConvertible, Sendable {
  case javaScriptCore = "JavaScriptCore"
  case quickJS = "QuickJS"

  var description: String { rawValue }

  func run<Assertion: ScriptEngineAssertion>(_ assertion: Assertion.Type) async {
    switch self {
    case .javaScriptCore:
      await assertion.run(JSCContext.self)
    case .quickJS:
      await assertion.run(QJSContext.self)
    }
  }
}

/// Forces a collection on GC engines (JSC); reference-counted engines need
/// no collection hook (the creation reference is already the root). Kept in
/// this file so engine-agnostic contract tests do not import
/// `JavaScriptCore` and collide with its ObjC `JSContext` names.
func stage3CollectGarbageIfSupported<C: SwiftJavaScript.JSContext>(_ context: C) {
  (context as? JSCContext)?.collectGarbage()
}

/// The two context-data-box hooks the contract tests drive without an actor
/// window. The handle layer now lives in each engine module, so this target
/// names just the surface it needs instead of one engine's runtime driver.
protocol ContextDataStorageBoxDriver: Sendable {
  func contextDataStorageBox() -> JSContextDataStorageBox?
  func installContextDataStorageBox(_ storage: JSContextDataStorageBox?)
}

extension JSCContextHandle: ContextDataStorageBoxDriver {}
extension QJSContextHandle: ContextDataStorageBoxDriver {}

/// The concrete engine's runtime driver behind a generic context.
///
/// The driver and its handle-typed members are engine implementation details
/// rather than `JSContext` requirements, so tests that must touch its hooks
/// dispatch on the concrete engine instead of widening the protocol surface.
func engineRuntimeDriver<C: SwiftJavaScript.JSContext>(
  _ context: C
) -> (any ContextDataStorageBoxDriver)? {
  if let context = context as? JSCContext {
    return context.driverContextHandle
  }
  if let context = context as? QJSContext {
    return context.driverContextHandle
  }
  return nil
}

/// Forces a collection regardless of engine: JSC has a synchronous
/// `JSGarbageCollect`, QuickJS exposes its cycle collector as `JS_RunGC`
/// (`QJSVirtualMachine.gc()`).
///
/// Persistent-binding tests use this to prove two complementary contracts:
/// a live binding roots its value (strong v1 semantics, design §4.4), and a
/// released QuickJS binding no longer does. JSC's C API has no host-side
/// weak reference, so post-release collectability is only observable on the
/// reference-counted engine; JSC covers the rooting half.
func stage4CollectGarbage<C: SwiftJavaScript.JSContext>(_ context: C) {
  if let context = context as? JSCContext {
    context.collectGarbage()
  } else if let context = context as? QJSContext {
    // Reached only for a QuickJS context: the cast is exact.
    context.virtualMachine.gc()
  }
}

/// An engine-agnostic assertion: generic over the context, which names every
/// other type of its engine (`C.Value`, `C.VirtualMachine`, ...).
protocol ScriptEngineAssertion {
  // Qualified: the engine modules are imported here, and their ObjC/engine
  // names shadow the core protocol names in this file.
  static func run<C: SwiftJavaScript.JSContext>(_ context: C.Type) async
}

import JavaScriptCore
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
/// `JavaScriptCore` and collide with `JSContextLegacy`/`JSType` names.
func stage3CollectGarbageIfSupported(_ contextHandle: any JSContextRuntimeDriver) {
  if let contextHandle = contextHandle as? JSCContextHandle {
    // `JSGarbageCollect` takes a `JSContextRef`, not the context group.
    JSGarbageCollect(contextHandle.ref)
  }
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
func stage4CollectGarbage<VM: SwiftJavaScript.JSVirtualMachine>(
  _ virtualMachine: VM,
  contextHandle: any JSContextRuntimeDriver
) {
  if let contextHandle = contextHandle as? JSCContextHandle {
    JSGarbageCollect(contextHandle.ref)
  } else if let virtualMachine = virtualMachine as? QJSVirtualMachine {
    // Reached only for a QuickJS VM: the cast is exact.
    virtualMachine.gc()
  }
}

/// An engine-agnostic assertion: generic over the context, which names every
/// other type of its engine (`C.Value`, `C.VirtualMachine`, ...).
protocol ScriptEngineAssertion {
  // Qualified: this file imports the `JavaScriptCore` module, whose ObjC
  // `JSContext` shadows the core protocol name here.
  static func run<C: SwiftJavaScript.JSContext>(_ context: C.Type) async
}

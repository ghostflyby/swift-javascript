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
      await assertion.run(JavaScriptCoreEngine.self)
    case .quickJS:
      await assertion.run(QuickJSEngine.self)
    }
  }
}

/// Forces a collection on GC engines (JSC); reference-counted engines need
/// no collection hook (the creation reference is already the root). Kept in
/// this file so engine-agnostic contract tests do not import
/// `JavaScriptCore` and collide with `JSContext`/`JSType` names.
func stage3CollectGarbageIfSupported(_ contextHandle: any JSContextRuntimeDriver) {
  if let contextHandle = contextHandle as? JavaScriptCoreContextHandle {
    // `JSGarbageCollect` takes a `JSContextRef`, not the context group.
    JSGarbageCollect(contextHandle.ref)
  }
}

/// Forces a collection regardless of engine: JSC has a synchronous
/// `JSGarbageCollect`, QuickJS exposes its cycle collector as
/// `JS_RunGC` (`JSVirtualMachine.gc()`).
///
/// Persistent-binding tests use this to prove two complementary contracts:
/// a live binding roots its value (strong v1 semantics, design §4.4), and a
/// released QuickJS binding no longer does. JSC's C API has no host-side
/// weak reference, so post-release collectability is only observable on the
/// reference-counted engine; JSC covers the rooting half.
func stage4CollectGarbage<E: JSEngine>(
  in virtualMachine: SwiftJavaScript.JSVirtualMachine<E>,
  contextHandle: any JSContextRuntimeDriver
) {
  if let contextHandle = contextHandle as? JavaScriptCoreContextHandle {
    JSGarbageCollect(contextHandle.ref)
  } else if let virtualMachine = virtualMachine
    as? SwiftJavaScript.JSVirtualMachine<QuickJSEngine>
  {
    // Reached only when `E == QuickJSEngine`: the cast is exact.
    virtualMachine.gc()
  }
}

protocol ScriptEngineAssertion {
  static func run<E: JSEngine>(_ engine: E.Type) async where E.Engine == E
}

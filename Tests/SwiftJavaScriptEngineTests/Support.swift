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

protocol ScriptEngineAssertion {
  static func run<E: JSEngine>(_ engine: E.Type) async where E.Engine == E
}

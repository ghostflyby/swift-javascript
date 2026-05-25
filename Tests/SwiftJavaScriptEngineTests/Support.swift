@testable import SwiftJavaScript
import SwiftyJavaScriptCore
import SwiftyQuickJS

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

protocol ScriptEngineAssertion {
  static func run<E: JSEngine>(_ engine: E.Type) async where E.Engine == E
}

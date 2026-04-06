import JavaScriptCore

extension JSResult where Value == SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
  consuming func toPrivateResult() -> JSResult<JSValueRef> {
    switch consume self {
    case .value(let v):
      return .value(v.takeRef())
    case .exception(let e):
      return .exception(e.takeRef())
    }
  }
}

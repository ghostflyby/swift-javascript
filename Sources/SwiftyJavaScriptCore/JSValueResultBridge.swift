extension JSResult where Value == SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
  consuming func toPrivateResult() -> JSResult<JavaScriptCoreValueRef> {
    switch consume self {
    case .value(let v):
      return .value(v.takeRef())
    case .exception(let e):
      return .exception(e.takeRef())
    }
  }

  static func from(
    handleResult: JSResult<JSValueHandle<JavaScriptCoreEngine>>?
  ) -> Self {
    bridgeHandleResult(handleResult)
  }
}

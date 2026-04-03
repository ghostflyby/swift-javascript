public typealias JSResult = SwiftJavaScript.JSResultPayload<JSValue>
typealias JSPrivateResult = SwiftJavaScript.JSResultPayload<JavaScriptCoreValueRef>

extension JSResult {
  consuming func toPrivateResult() -> JSPrivateResult {
    switch consume self {
    case .value(let v):
      return .value(v.takeRef())
    case .exception(let e):
      return .exception(e.takeRef())
    }
  }
}

extension JSResult {
  static func from(
    handleResult: SwiftJavaScript.JSResultPayload<JSValueHandle<JavaScriptCoreEngine>>?
  ) -> JSResult {
    SwiftJavaScript.bridgeHandleResult(handleResult)
  }
}

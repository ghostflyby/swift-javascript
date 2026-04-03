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
  static func from(handleResult: JSResultHandle<JavaScriptCoreEngine>?) -> JSResult {
    guard let handleResult else {
      preconditionFailure("JSResult handle bridge unexpectedly returned nil")
    }

    switch handleResult {
    case .value(let value):
      return .value(JSValue(handleValue: value))
    case .exception(let exception):
      return .exception(JSValue(handleValue: exception))
    }
  }
}

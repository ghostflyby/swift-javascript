public typealias JSResult = SwiftJavaScript.JSResultPayload<JSValue>

enum JSPrivateResult: @unchecked Sendable {
  case value(JavaScriptCoreValueRef)
  case exception(JavaScriptCoreValueRef)
}

extension JSResult {
  consuming func toPrivateResult() -> JSPrivateResult {
    switch consume self {
    case .value(let v):
      return .value(v.retainedRef())
    case .exception(let e):
      return .exception(e.retainedRef())
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

  static func from(driverResult: JSDriverResult<JavaScriptCoreRawValue>) -> JSResult {
    switch driverResult {
    case .value(let value):
      return .value(JSValue(handleValue: JavaScriptCoreBackendDriver.valueHandle(from: value)))
    case .exception(let exception):
      return .exception(
        JSValue(handleValue: JavaScriptCoreBackendDriver.valueHandle(from: exception)))
    }
  }
}

import JavaScriptCore

extension JSResult where Value == SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
  consuming func toPrivateResult() -> JSResult<JSValueRef> {
    switch consume self {
    case .value(let v):
      return .value(v.callbackRef())
    case .exception(let e):
      return .exception(e.callbackRef())
    }
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  /// Hands the raw value reference back to JavaScriptCore callback ABI.
  ///
  /// The returned `JSValueRef` remains managed by JavaScriptCore. Consume the
  /// Swift wrapper so its `deinit` does not unprotect a value that was not
  /// explicitly protected for long-term Swift ownership.
  consuming func callbackRef() -> JSValueRef {
    takeRef()
  }
}

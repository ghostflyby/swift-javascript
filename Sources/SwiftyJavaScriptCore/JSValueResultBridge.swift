import JavaScriptCore

extension JSResult where Value == SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
  borrowing func toPrivateResult() -> JSResult<JSValueRef> {
    switch self {
    case .value(let v):
      return .value(v.borrowedRef())
    case .exception(let e):
      return .exception(e.borrowedRef())
    }
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  /// Hands the raw value reference back to JavaScriptCore callback ABI.
  ///
  /// `JSValue` is a non-owning local view: the returned `JSValueRef` stays
  /// owned by the arena (or engine callback frame) that backs the handle, so
  /// there is no protection to drop and nothing to consume.
  borrowing func callbackRef() -> JSValueRef {
    borrowedRef()
  }
}

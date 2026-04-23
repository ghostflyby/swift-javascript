import JavaScriptCore

extension JSResult where Value == SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
  @_lifetime(immortal)
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
  /// JavaScriptCore callback returns borrow `JSValueRef`; they do not consume a
  /// `JSValueProtect` retain. Let `self` deinitialize so Swift-side ownership is
  /// balanced before handing the raw ref back to JavaScriptCore.
  consuming func callbackRef() -> JSValueRef {
    ref
  }
}

import JavaScriptCore

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  /// Wrap a JavaScriptCore value reference into handle-backed value storage.
  /// - Parameters:
  ///   - ref: The JSValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(
    ref: JSValueRef,
    ctx: isolated SwiftJavaScript.JSContext<JavaScriptCoreEngine>
  ) {
    let instant = SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>(
      handle: ctx.driverContextHandle
    )
    self.init(ref: ref, in: instant)
  }

  init(
    ref: JSValueRef,
    ctx: borrowing SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.init(ref: ref, in: ctx)
  }

  /// tansfer ownership of the underlying JSValueRef out of this value, consuming self in the process.
  consuming func takeRef() -> JSValueRef {
    return _rawValue.ref
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  init(
    ref: JSValueRef,
    in context: borrowing SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>
  ) {
    let handle = JavaScriptCoreValueHandle(
      ref: ref,
      contextRef: context.driverContextHandle.ref
    )
    self.init(handleValue: handle)
  }

  var ref: JSValueRef {
    _rawValue.ref
  }
}

import JavaScriptCore

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  /// Wrap a JavaScriptCore value reference into handle-backed value storage.
  /// - Parameters:
  ///   - ref: The JSValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  @_lifetime(immortal)
  init(
    ref: JSValueRef,
    ctx: borrowing isolated SwiftJavaScript.JSContext<JavaScriptCoreEngine>
  ) {
    let handle = JavaScriptCoreValueHandle(
      ref: ref,
      contextRef: ctx.driverContextHandle.ref
    )
    self.init(handleValue: handle)
  }

  @_lifetime(borrow ctx)
  init(
    ref: JSValueRef,
    ctx: borrowing SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.init(ref: ref, in: ctx)
  }

  /// tansfer ownership of the underlying JSValueRef out of this value, consuming self in the process.
  consuming func takeRef() -> JSValueRef {
    return takeHandle().ref
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  @_lifetime(borrow context)
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
    borrowHandle().ref
  }
}

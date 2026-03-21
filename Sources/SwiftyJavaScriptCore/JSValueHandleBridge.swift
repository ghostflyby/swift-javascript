extension JSValue {
  var ref: JavaScriptCoreValueRef {
    _rawValue.ref
  }

  var ctx: JavaScriptCoreContextRef {
    _rawValue.context.ref
  }

  /// Wrap a JavaScriptCore value reference into backend raw value storage.
  /// - Parameters:
  ///   - ref: The JavaScriptCoreValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(ref: JavaScriptCoreValueRef, ctx: isolated JSContext = #isolation) {
    self._rawValue = JavaScriptCoreRawValue(
      ref: ref,
      context: JavaScriptCoreRawContext(borrowing: ctx.globalContextRef)
    )
  }

  init(ref: JavaScriptCoreValueRef, ctx: borrowing JSInstantContext) {
    self._rawValue = JavaScriptCoreRawValue(
      ref: ref,
      context: JavaScriptCoreRawContext(borrowing: ctx.globalContextRef)
    )
  }

  consuming func retainedRef() -> JavaScriptCoreValueRef {
    ref
  }

  init(handleValue: JSValueHandle<JavaScriptCoreEngine>) {
    guard let rawValue: JavaScriptCoreRawValue = handleValue.opaqueHandle() else {
      preconditionFailure("JSValue handle did not contain JavaScriptCoreRawValue")
    }
    self.init(rawValue: rawValue)
  }

  init(rawValue: JavaScriptCoreRawValue) {
    self._rawValue = rawValue
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    if _rawValue.context.ref == context.ref {
      return _rawValue
    }
    return JavaScriptCoreRawValue(ref: ref, context: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: rawValue(in: context.driverContext))
  }
}

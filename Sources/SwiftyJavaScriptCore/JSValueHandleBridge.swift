extension JSValue {
  var ref: JavaScriptCoreValueRef {
    _rawValue.ref
  }

  /// Wrap a JavaScriptCore value reference into backend raw value storage.
  /// - Parameters:
  ///   - ref: The JavaScriptCoreValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(ref: JavaScriptCoreValueRef, ctx: isolated JSContext = #isolation) {
    let instant = JSInstantContext(ctx: ctx.globalContextRef)
    self._rawValue = _JSValueStorage(ref: ref, in: instant)
  }

  init(ref: JavaScriptCoreValueRef, ctx: borrowing JSInstantContext) {
    self._rawValue = _JSValueStorage(ref: ref, in: ctx)
  }

  consuming func retainedRef() -> JavaScriptCoreValueRef {
    ref
  }

  init(handleValue: JSValueHandle<JavaScriptCoreEngine>) {
    self._rawValue = _JSValueStorage(handle: handleValue)
  }

  init(rawValue: JavaScriptCoreRawValue) {
    self._rawValue = _JSValueStorage(rawValue: rawValue)
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    _rawValue.rawValue(in: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    _ = context
    return _rawValue.valueHandle()
  }
}

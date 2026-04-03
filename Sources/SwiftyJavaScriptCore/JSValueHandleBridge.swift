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
    guard let rawStorage = _JSValueStorage.fromHandle(handleValue) else {
      preconditionFailure("JSValue handle did not contain JavaScriptCoreRawValue")
    }
    self._rawValue = rawStorage
  }

  init(rawValue: JavaScriptCoreRawValue) {
    self._rawValue = _JSValueStorage(rawValue: rawValue)
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    _rawValue.rawValue(in: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    _rawValue.valueHandle(in: context)
  }
}

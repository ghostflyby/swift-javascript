struct _JSValueRawStorage: ~Copyable {
  let ref: JavaScriptCoreValueRef
}

extension JSValue {
  var ref: JavaScriptCoreValueRef {
    _rawValue.ref
  }

  /// Wrap a JavaScriptCore value reference into backend raw value storage.
  /// - Parameters:
  ///   - ref: The JavaScriptCoreValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(ref: JavaScriptCoreValueRef, ctx: isolated JSContext = #isolation) {
    self._rawValue = _JSValueRawStorage(ref: ref)
  }

  init(ref: JavaScriptCoreValueRef, ctx: borrowing JSInstantContext) {
    self._rawValue = _JSValueRawStorage(ref: ref)
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
    self._rawValue = _JSValueRawStorage(ref: rawValue.ref)
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    return JavaScriptCoreRawValue(ref: ref, context: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: rawValue(in: context.driverContext))
  }
}

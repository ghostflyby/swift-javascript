struct _JSValueRawStorage: ~Copyable {
  let ref: JavaScriptCoreValueRef

  init(ref: JavaScriptCoreValueRef) {
    self.ref = ref
  }

  init(rawValue: JavaScriptCoreRawValue) {
    self.ref = rawValue.ref
  }

  static func fromHandle(
    _ handle: JSValueHandle<JavaScriptCoreEngine>
  ) -> _JSValueRawStorage? {
    guard let rawValue: JavaScriptCoreRawValue = handle.opaqueHandle() else {
      return nil
    }
    return _JSValueRawStorage(rawValue: rawValue)
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: ref, context: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: rawValue(in: context.driverContext))
  }
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
    _ = ctx
  }

  init(ref: JavaScriptCoreValueRef, ctx: borrowing JSInstantContext) {
    self._rawValue = _JSValueRawStorage(ref: ref)
    _ = ctx
  }

  consuming func retainedRef() -> JavaScriptCoreValueRef {
    ref
  }

  init(handleValue: JSValueHandle<JavaScriptCoreEngine>) {
    guard let rawStorage = _JSValueRawStorage.fromHandle(handleValue) else {
      preconditionFailure("JSValue handle did not contain JavaScriptCoreRawValue")
    }
    self._rawValue = rawStorage
  }

  init(rawValue: JavaScriptCoreRawValue) {
    self._rawValue = _JSValueRawStorage(rawValue: rawValue)
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    _rawValue.rawValue(in: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    _rawValue.valueHandle(in: context)
  }
}

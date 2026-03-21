extension JSValue {
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

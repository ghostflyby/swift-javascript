extension JSValue {
  init(handleValue: JSValueHandle<JavaScriptCoreEngine>) {
    guard let rawValue: JavaScriptCoreRawValue = handleValue.opaqueHandle() else {
      preconditionFailure("JSValue handle did not contain JavaScriptCoreRawValue")
    }
    self.init(rawValue: rawValue)
  }

  init(rawValue: JavaScriptCoreRawValue) {
    self.init(ref: rawValue.ref, ctx: JSInstantContext(ctx: rawValue.context.ref))
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: ref, context: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: rawValue(in: context.driverContext))
  }
}

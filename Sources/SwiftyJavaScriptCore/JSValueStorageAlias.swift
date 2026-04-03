typealias _JSValueStorage = JSEngineValueStorage<JavaScriptCoreEngine>

extension _JSValueStorage {
  init(ref: JavaScriptCoreValueRef, in context: borrowing JSInstantContext) {
    guard
      let handle = JavaScriptCoreBackendDriver.valueHandle(
        from: ref,
        in: context.driverContextHandle
      )
    else {
      preconditionFailure("JSValue storage could not create value handle")
    }
    self.init(handle: handle)
  }

  init(rawValue: JavaScriptCoreRawValue) {
    let context = JSInstantContext(ctx: rawValue.context.ref)
    self.init(ref: JavaScriptCoreBackendDriver.valueRef(from: rawValue), in: context)
  }

  static func fromHandle(
    _ handle: JSValueHandle<JavaScriptCoreEngine>
  ) -> _JSValueStorage {
    _JSValueStorage(handle: handle)
  }

  var ref: JavaScriptCoreValueRef {
    guard let ref = JavaScriptCoreBackendDriver.valueRef(from: valueHandle()) else {
      preconditionFailure("JSValue storage handle has no value ref")
    }
    return ref
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    JavaScriptCoreBackendDriver.rawValue(from: ref, in: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    _ = context
    return valueHandle()
  }
}

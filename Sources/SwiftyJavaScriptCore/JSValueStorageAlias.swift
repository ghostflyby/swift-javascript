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
    self.init(handle: JavaScriptCoreBackendDriver.valueHandle(from: rawValue))
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
}

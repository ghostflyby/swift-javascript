extension JSValue {
  var ref: JavaScriptCoreValueRef {
    _rawValue.ref
  }

  /// Wrap a JavaScriptCore value reference into handle-backed value storage.
  /// - Parameters:
  ///   - ref: The JavaScriptCoreValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(ref: JavaScriptCoreValueRef, ctx: isolated JSContext) {
    let instant = JSInstantContext(ctx: ctx.globalContextRef)
    self.init(storage: JSEngineValueStorage<JavaScriptCoreEngine>(ref: ref, in: instant))
  }

  init(ref: JavaScriptCoreValueRef, ctx: borrowing JSInstantContext) {
    self.init(storage: JSEngineValueStorage<JavaScriptCoreEngine>(ref: ref, in: ctx))
  }

  consuming func takeRef() -> JavaScriptCoreValueRef {
    let handle = _rawValue.valueHandle()
    guard let ref = JavaScriptCoreBackendDriver.retainedValueRef(from: handle) else {
      preconditionFailure("JSValue storage handle has no value ref")
    }
    return ref
  }

  init(handleValue: JSValueHandle<JavaScriptCoreEngine>) {
    self.init(storage: JSEngineValueStorage<JavaScriptCoreEngine>(handle: handleValue))
  }

  func valueHandle() -> JSValueHandle<JavaScriptCoreEngine> {
    return _rawValue.valueHandle()
  }
}

extension JSEngineValueStorage where E == JavaScriptCoreEngine {
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

  var ref: JavaScriptCoreValueRef {
    guard let ref = JavaScriptCoreBackendDriver.valueRef(from: valueHandle()) else {
      preconditionFailure("JSValue storage handle has no value ref")
    }
    return ref
  }
}

extension JSValue {
  /// Wrap a JavaScriptCore value reference into handle-backed value storage.
  /// - Parameters:
  ///   - ref: The JavaScriptCoreValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(ref: JavaScriptCoreValueRef, ctx: isolated JSContext) {
    let instant = JSInstantContext(handle: ctx.driverContextHandle)
    self.init(ref: ref, in: instant)
  }

  init(ref: JavaScriptCoreValueRef, ctx: borrowing JSInstantContext) {
    self.init(ref: ref, in: ctx)
  }

  consuming func takeRef() -> JavaScriptCoreValueRef {
    guard let ref = JavaScriptCoreEngine.retainedValueRef(from: _rawValue) else {
      preconditionFailure("JSValue storage handle has no value ref")
    }
    return ref
  }
}

extension JSEngineValue where E == JavaScriptCoreEngine {
  init(ref: JavaScriptCoreValueRef, in context: borrowing JSInstantContext) {
    guard
      let handle = JavaScriptCoreEngine.valueHandle(
        from: ref,
        in: context.driverContextHandle
      )
    else {
      preconditionFailure("JSValue storage could not create value handle")
    }
    self.init(handleValue: handle)
  }

  var ref: JavaScriptCoreValueRef {
    guard let ref = JavaScriptCoreEngine.valueRef(from: _rawValue) else {
      preconditionFailure("JSValue storage handle has no value ref")
    }
    return ref
  }
}

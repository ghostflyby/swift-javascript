import JavaScriptCore

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  /// Wrap a JavaScriptCore value reference into handle-backed value storage.
  /// - Parameters:
  ///   - ref: The JSValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(
    ref: JSValueRef,
    ctx: isolated SwiftJavaScript.JSContext<JavaScriptCoreEngine>
  ) {
    let instant = SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>(
      handle: ctx.driverContextHandle
    )
    self.init(ref: ref, in: instant)
  }

  init(
    ref: JSValueRef,
    ctx: borrowing SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.init(ref: ref, in: ctx)
  }

  consuming func takeRef() -> JSValueRef {
    guard let ref = JavaScriptCoreEngine.retainedValueRef(from: _rawValue) else {
      preconditionFailure(
        "SwiftJavaScript.JSValue<JavaScriptCoreEngine> storage handle has no value ref")
    }
    return ref
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  init(
    ref: JSValueRef,
    in context: borrowing SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>
  ) {
    guard
      let handle = JavaScriptCoreEngine.valueHandle(
        from: ref,
        in: context.driverContextHandle
      )
    else {
      preconditionFailure(
        "SwiftJavaScript.JSValue<JavaScriptCoreEngine> storage could not create value handle")
    }
    self.init(handleValue: handle)
  }

  var ref: JSValueRef {
    guard let ref = JavaScriptCoreEngine.valueRef(from: _rawValue) else {
      preconditionFailure(
        "SwiftJavaScript.JSValue<JavaScriptCoreEngine> storage handle has no value ref")
    }
    return ref
  }
}

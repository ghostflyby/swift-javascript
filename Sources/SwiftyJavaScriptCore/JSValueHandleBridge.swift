extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  /// Wrap a JavaScriptCore value reference into handle-backed value storage.
  /// - Parameters:
  ///   - ref: The JavaScriptCoreValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(
    ref: JavaScriptCoreValueRef,
    ctx: isolated SwiftJavaScript.JSContext<JavaScriptCoreEngine>
  ) {
    let instant = SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>(
      handle: ctx.driverContextHandle
    )
    self.init(ref: ref, in: instant)
  }

  init(
    ref: JavaScriptCoreValueRef,
    ctx: borrowing SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.init(ref: ref, in: ctx)
  }

  consuming func takeRef() -> JavaScriptCoreValueRef {
    guard let ref = JavaScriptCoreEngine.retainedValueRef(from: _rawValue) else {
      preconditionFailure(
        "SwiftJavaScript.JSValue<JavaScriptCoreEngine> storage handle has no value ref")
    }
    return ref
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  init(
    ref: JavaScriptCoreValueRef,
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

  var ref: JavaScriptCoreValueRef {
    guard let ref = JavaScriptCoreEngine.valueRef(from: _rawValue) else {
      preconditionFailure(
        "SwiftJavaScript.JSValue<JavaScriptCoreEngine> storage handle has no value ref")
    }
    return ref
  }
}

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

  /// Borrow the underlying raw reference for a JavaScriptCore callback ABI.
  ///
  /// `JSValue` is a non-owning local view, so no ownership is transferred;
  /// the arena (or the engine's callback frame) that backs the handle keeps
  /// the reference alive.
  borrowing func borrowedRef() -> JSValueRef {
    borrowHandle().ref
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  init(
    ref: JSValueRef,
    in context: borrowing SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>
  ) {
    let handle = JavaScriptCoreValueHandle(
      ref: ref
    )
    self.init(handleValue: handle, in: context.driverContextHandle)
  }

  var ref: JSValueRef {
    borrowHandle().ref
  }
}

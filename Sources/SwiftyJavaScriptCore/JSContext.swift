@preconcurrency import JavaScriptCore

extension SwiftJavaScript.JSContext where E == JavaScriptCoreEngine {
  public func withIsolatedGlobalObject<R: Sendable>(
    _ body:
      @Sendable (
        isolated SwiftJavaScript.JSContext<JavaScriptCoreEngine>,
        borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
      ) -> R
  ) -> R {
    let globalObject = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(
      ref: driverContextHandle.globalObjectRef, ctx: self)
    return body(self, globalObject)
  }
}

extension SwiftJavaScript.JSContext where E == JavaScriptCoreEngine {
  nonisolated var globalContextRef: JSGlobalContextRef {
    driverContextHandle.ref
  }
}

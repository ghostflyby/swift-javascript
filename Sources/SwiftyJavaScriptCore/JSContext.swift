@preconcurrency import JavaScriptCore

public typealias JSContext = JSEngineContext<JavaScriptCoreEngine>

extension JSEngineContext where E == JavaScriptCoreEngine {
  public func withIsolatedGlobalObject<R: Sendable>(
    _ body:
      @Sendable (isolated JSContext, borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>) -> R
  ) -> R {
    let globalObject = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(
      ref: driverContextHandle.globalObjectRef, ctx: self)
    return body(self, globalObject)
  }
}

extension JSEngineContext where E == JavaScriptCoreEngine {
  nonisolated var globalContextRef: JSGlobalContextRef {
    driverContextHandle.ref
  }
}

@preconcurrency import JavaScriptCore

public typealias JSContext = JSEngineContext<JavaScriptCoreEngine>

extension JSEngineContext where E == JavaScriptCoreEngine {
  public init(virtualMachine: SwiftJavaScript.JSVirtualMachine<JavaScriptCoreEngine>) {
    guard
      let driverContextHandle = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(
        in: virtualMachine.driverRuntimeHandle)
    else {
      preconditionFailure("JSContext could not create context handle from runtime")
    }

    self.init(virtualMachine: virtualMachine, driverContextHandle: driverContextHandle)
    self.driverContextHandle.bind(owner: self)
  }

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

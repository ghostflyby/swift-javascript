@preconcurrency import JavaScriptCore

public typealias JSContext = JSEngineContext<JavaScriptCoreEngine>

extension JSEngineContext where E == JavaScriptCoreEngine {
  public init(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>) {
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
    _ body: @Sendable (isolated JSContext, borrowing JSValue) -> R
  ) -> R {
    let globalObject = JSValue(ref: driverContextHandle.globalObjectRef, ctx: self)
    return body(self, globalObject)
  }
}

extension JSEngineContext where E == JavaScriptCoreEngine {
  nonisolated var globalContextRef: JSGlobalContextRef {
    driverContextHandle.ref
  }
}

extension JSInstantContext where E == JavaScriptCoreEngine {
  init(ctx: JavaScriptCoreContextRef) {
    self.init(
      handle: JavaScriptCoreContextHandle(borrowing: ctx)
    )
  }

  public var globalContextRef: JavaScriptCoreGlobalContextRef {
    driverContextHandle.ref
  }
}

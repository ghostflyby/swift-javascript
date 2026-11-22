import JavaScriptCore

extension JSInstantContext where E == JavaScriptCoreEngine {
  @available(*, noasync)
  init(ctx: JSContextRef) {
    self.init(
      handle: JavaScriptCoreContextHandle(borrowing: ctx)
    )
  }
}

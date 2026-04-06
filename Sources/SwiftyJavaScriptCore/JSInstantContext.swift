import JavaScriptCore

extension JSInstantContext where E == JavaScriptCoreEngine {
  init(ctx: JSContextRef) {
    self.init(
      handle: JavaScriptCoreContextHandle(borrowing: ctx)
    )
  }
}

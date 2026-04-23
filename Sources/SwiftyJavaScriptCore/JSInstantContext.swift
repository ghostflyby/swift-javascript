import JavaScriptCore

extension JSInstantContext where E == JavaScriptCoreEngine {
  @_lifetime(immortal)
  init(ctx: JSContextRef) {
    self.init(
      handle: JavaScriptCoreContextHandle(borrowing: ctx)
    )
  }
}

import JavaScriptCore

public struct JSCallbackContext: ~Copyable {
  public let globalContextRef: JSGlobalContextRef

  init(ctx: JSContextRef) {
    self.globalContextRef = ctx
  }
}

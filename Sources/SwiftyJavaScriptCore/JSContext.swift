@preconcurrency import JavaScriptCore

public actor JSContext {
  nonisolated let peer: JavaScriptCore.JSContext
  let globalObjectRef: JSObjectRef
  public let virtualMachine: JSVirtualMachine
  nonisolated public let unownedExecutor: UnownedSerialExecutor

  public init(virtualMachine: JSVirtualMachine) {
    self.virtualMachine = virtualMachine
    let context = JavaScriptCore.JSContext(virtualMachine: virtualMachine.peer)!
    self.peer = context
    globalObjectRef = context.globalObject!.jsValueRef
    self.unownedExecutor = virtualMachine.unownedExecutor
  }

  public func withGlobalObject(_ body: (borrowing JSValue) -> Void) {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    body(globalObject)
  }

}

extension JSContext {
  static let privateExtraDataKey = JSStringValue(
    "SwiftyJavaScriptCore.JSContext.PrivateExtraDataKey")
}

extension JSContext: Hashable {
  nonisolated public static func == (lhs: JSContext, rhs: JSContext) -> Bool {
    lhs.globalContextRef == rhs.globalContextRef
  }

  nonisolated public func hash(into hasher: inout Hasher) {
    hasher.combine(globalContextRef)
  }
}

extension JSContext {
  nonisolated var globalContextRef: JSGlobalContextRef {
    peer.jsGlobalContextRef
  }
}

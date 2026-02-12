@preconcurrency import JavaScriptCore

public actor JSContext {
  nonisolated let peer: JavaScriptCore.JSContext
  let globalObjectRef: JSObjectRef
  let functionClass: JSClassRef
  public let virtualMachine: JSVirtualMachine
  nonisolated public let unownedExecutor: UnownedSerialExecutor

  public init(virtualMachine: JSVirtualMachine) {
    self.virtualMachine = virtualMachine
    let context = JavaScriptCore.JSContext(virtualMachine: virtualMachine.peer)!
    self.peer = context
    globalObjectRef = context.globalObject!.jsValueRef
    var def = functionClassDef
    functionClass = JSClassCreate(&def)
    self.unownedExecutor = virtualMachine.unownedExecutor
  }

  public func withGlobalObject(_ body: (borrowing JSValue) -> Void) {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    body(globalObject)
  }

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

private let functionCallback: JSObjectCallAsFunctionCallback = {
  c, f, this, count, args, exception in
  // FIXME: use the real context instead of creating a new one
  let context = JSContext(virtualMachine: JSVirtualMachine())
  let f = SendableBoxUnsafe(f!)
  let this = SendableBoxUnsafe(this!)
  let args = SendableBoxUnsafe(args!)

  let v = context.assumeIsolated { context in
    let function = JSValue(ref: f.value, ctx: context)
    let this = JSValue(ref: this.value, ctx: context)
    let args = JSArguments(pointer: args.value, count: Int(count))
    let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(
      JSObjectGetPrivate(f.value)!
    )
    .takeUnretainedValue().value
    return callback(
      context,
      function,
      this,
      args
    ).toPrivateResult()
  }
  switch v {
  case .value(let r):
    return r
  case .exception(let e):
    exception?.pointee = e
    return JSValueMakeUndefined(c!)
  }
}
private let functionClassDef = {
  var def = kJSClassDefinitionEmpty
  def.callAsFunction = functionCallback
  def.finalize = { ref in
    let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(JSObjectGetPrivate(ref)!)
      .takeRetainedValue()
    // release the callback
    _ = callback.value
  }
  return def
}()

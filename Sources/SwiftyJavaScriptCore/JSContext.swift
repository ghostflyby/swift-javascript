@preconcurrency import JavaScriptCore

public actor JSContext {
  nonisolated let peer: JavaScriptCore.JSContext
  let globalObjectRef: JSObjectRef
  let functionClass: SendableBoxUnsafe<JSClassRef>
  let globalObjectClass: SendableBoxUnsafe<JSClassRef>
  public let virtualMachine: JSVirtualMachine
  nonisolated public let unownedExecutor: UnownedSerialExecutor

  public init(virtualMachine: JSVirtualMachine) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor

    var kJSClassDefinitionEmpty = kJSClassDefinitionEmpty
    let cls = JSClassCreate(&kJSClassDefinitionEmpty)!
    let ref = JSGlobalContextCreateInGroup(virtualMachine.peer, cls)
    globalObjectClass = SendableBoxUnsafe(cls)

    self.peer = JavaScriptCore.JSContext(jsGlobalContextRef: ref)!

    globalObjectRef = peer.globalObject!.jsValueRef
    var def = functionClassDef
    functionClass = SendableBoxUnsafe(JSClassCreate(&def))

    JSObjectSetPrivate(globalObjectRef, Unmanaged.passUnretained(self).toOpaque())

  }

  public func withGlobalObject(_ body: (borrowing JSValue) -> Void) {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    body(globalObject)
  }

  public func withIsolatedGlobalObject<R: Sendable>(
    _ body: @Sendable (isolated JSContext, borrowing JSValue) -> R
  ) -> R {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    return body(self, globalObject)
  }

  public func withCallbackContext<R: ~Copyable, E: Error>(
    _ body: (borrowing JSCallbackContext) throws(E) -> R
  ) throws(E) -> R {
    let callbackContext = JSCallbackContext(ctx: globalContextRef)
    return try body(callbackContext)
  }

  deinit {
    JSGlobalContextRelease(peer.jsGlobalContextRef)
    JSClassRelease(functionClass.value)
    JSClassRelease(globalObjectClass.value)
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

  public func evaluateScript(_ script: String) -> JSResult {
    let scriptString = JSStringValue(script)
    return evaluateScript(scriptString, startingLineNumber: 1)
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    startingLineNumber: Int32 = 1
  ) -> JSResult where Script: JSString, Script: ~Copyable {
    evaluateScript(scriptRef: script.ref, sourceURLRef: nil, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult where Script: JSString, Script: ~Copyable {
    let sourceURLString = JSStringValue(sourceURL)
    return evaluateScript(
      script, sourceURL: sourceURLString, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<SourceURL>(
    _ script: String,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult where SourceURL: JSString, SourceURL: ~Copyable {
    let scriptString = JSStringValue(script)
    return evaluateScript(
      scriptString, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult {
    let scriptString = JSStringValue(script)
    let sourceURLString = JSStringValue(sourceURL)
    return evaluateScript(
      scriptString, sourceURL: sourceURLString, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<Script, SourceURL>(
    _ script: borrowing Script,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult
  where Script: JSString, Script: ~Copyable, SourceURL: JSString, SourceURL: ~Copyable {
    evaluateScript(
      scriptRef: script.ref, sourceURLRef: sourceURL.ref, startingLineNumber: startingLineNumber)
  }

  private func evaluateScript(
    scriptRef: JSStringRef,
    sourceURLRef: JSStringRef?,
    startingLineNumber: Int32
  ) -> JSResult {
    var exception: JSValueRef?
    let result = JSEvaluateScript(
      globalContextRef,
      scriptRef,
      nil,
      sourceURLRef,
      startingLineNumber,
      &exception
    )

    if let exception {
      return .exception(JSValue(ref: exception, ctx: self))
    }

    if let result {
      return .value(JSValue(ref: result, ctx: self))
    }

    return .value(JSValue(undefinedIn: self))
  }
}

private let functionCallback: JSObjectCallAsFunctionCallback = {
  c, f, this, count, args, exception in
  let context = JSCallbackContext(ctx: c!)
  let functionRef = f!
  let thisRef = this!
  let argsRef = args!
  let function = JSValue(ref: functionRef, ctx: context)
  let this = JSValue(ref: thisRef, ctx: context)
  let jsArgs = JSArguments(pointer: argsRef, count: Int(count))
  let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(
    JSObjectGetPrivate(functionRef)!
  )
  .takeUnretainedValue().value
  let v = callback(
    context,
    function,
    this,
    jsArgs
  ).toPrivateResult()
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

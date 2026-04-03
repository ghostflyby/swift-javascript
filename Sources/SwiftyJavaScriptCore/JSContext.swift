@preconcurrency import JavaScriptCore

public actor JSContext {
  nonisolated let peer: JavaScriptCore.JSContext
  nonisolated let driverContextHandle: JSBorrowedContextHandle<JavaScriptCoreEngine>
  let globalObjectRef: JSObjectRef
  nonisolated let functionClass: SendableBoxUnsafe<JSClassRef>
  let globalObjectClass: SendableBoxUnsafe<JSClassRef>
  public let virtualMachine: JSVirtualMachine
  nonisolated public let unownedExecutor: UnownedSerialExecutor

  public init(virtualMachine: JSVirtualMachine) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor

    guard
      let rawRuntime: JavaScriptCoreRawRuntime = virtualMachine.driverRuntimeHandle
        .opaqueHandle()
    else {
      preconditionFailure("JSContext has invalid runtime handle")
    }

    var kJSClassDefinitionEmpty = kJSClassDefinitionEmpty
    let cls = JSClassCreate(&kJSClassDefinitionEmpty)!
    let ref = JSGlobalContextCreateInGroup(rawRuntime.ref, cls)!

    self.driverContextHandle = JSBorrowedContextHandle<JavaScriptCoreEngine>(
      _opaqueHandle: JavaScriptCoreRawContext(adopting: ref, runtime: rawRuntime)
    )
    globalObjectClass = SendableBoxUnsafe(cls)

    self.peer = JavaScriptCore.JSContext(jsGlobalContextRef: ref)!

    globalObjectRef = peer.globalObject!.jsValueRef
    functionClass = SendableBoxUnsafe(JavaScriptCoreEngine.makeFunctionClass())

    JSObjectSetPrivate(globalObjectRef, Unmanaged.passUnretained(self).toOpaque())

  }

  public func withGlobalObject(_ body: (borrowing JSValue) -> Void) {
    withInstantContext { instantContext in
      instantContext.withGlobalObject(body)
    }
  }

  public func withIsolatedGlobalObject<R: Sendable>(
    _ body: @Sendable (isolated JSContext, borrowing JSValue) -> R
  ) -> R {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    return body(self, globalObject)
  }

  public func withInstantContext<R: ~Copyable, E: Error>(
    _ body: (borrowing JSInstantContext) throws(E) -> R
  ) throws(E) -> R {
    let instantContext = JSInstantContext(handle: driverContextHandle)
    return try body(instantContext)
  }

  deinit {
    _ = driverContextHandle.releaseReference()
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

  public func makeString(_ value: String) -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeString(value)
    }
  }

  public func makeNumber(_ value: Double) -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeNumber(value)
    }
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeNumber(value)
    }
  }

  public func makeBoolean(_ value: Bool) -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeBoolean(value)
    }
  }

  public func makeNull() -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeNull()
    }
  }

  public func makeUndefined() -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeUndefined()
    }
  }

  public func makeObject() -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeObject()
    }
  }

  public func makeArray() -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeArray()
    }
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback
  ) -> JSValue {
    withInstantContext { instantContext in
      instantContext.makeFunction(named: name, callback: callback)
    }
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: SwiftJavaScript.JSPropertyAttributes = .none,
    callback: @escaping JSFunctionCallback
  ) {
    withInstantContext { instantContext in
      instantContext.installGlobalFunction(named: name, with: attributes, callback: callback)
    }
  }

  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: SwiftJavaScript.JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    withInstantContext { instantContext in
      instantContext.setGlobalProperty(value, forKey: key, with: attributes)
    }
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: SwiftJavaScript.JSPropertyAttributes = .none
  ) {
    withInstantContext { instantContext in
      instantContext.setGlobalProperty(value, forKey: key, using: converter, with: attributes)
    }
  }

  public func getGlobalProperty(forKey key: String) -> JSValue {
    return withInstantContext { instantContext in
      instantContext.getGlobalProperty(forKey: key)
    }
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: String,
    using converter: C.Type
  ) -> C.SwiftType {
    return withInstantContext { instantContext in
      instantContext.getGlobalProperty(forKey: key, using: converter)
    }
  }

  public func deleteGlobalProperty(forKey key: String) {
    withInstantContext { instantContext in
      instantContext.deleteGlobalProperty(forKey: key)
    }
  }

  public func hasGlobalProperty(_ key: String) -> Bool {
    return withInstantContext { instantContext in
      instantContext.hasGlobalProperty(key)
    }
  }

  public func evaluateScript(_ script: String) -> JSResult {
    withInstantContext { instantContext in
      instantContext.evaluateScript(script)
    }
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    startingLineNumber: Int32 = 1
  ) -> JSResult where Script: JSString, Script: ~Copyable {
    withInstantContext { instantContext in
      instantContext.evaluateScript(script, startingLineNumber: startingLineNumber)
    }
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult where Script: JSString, Script: ~Copyable {
    withInstantContext { instantContext in
      instantContext.evaluateScript(
        script, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
    }
  }

  public func evaluateScript<SourceURL>(
    _ script: String,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult where SourceURL: JSString, SourceURL: ~Copyable {
    withInstantContext { instantContext in
      instantContext.evaluateScript(
        script, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
    }
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult {
    withInstantContext { instantContext in
      instantContext.evaluateScript(
        script, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
    }
  }

  public func evaluateScript<Script, SourceURL>(
    _ script: borrowing Script,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult
  where Script: JSString, Script: ~Copyable, SourceURL: JSString, SourceURL: ~Copyable {
    withInstantContext { instantContext in
      instantContext.evaluateScript(
        script, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
    }
  }
}

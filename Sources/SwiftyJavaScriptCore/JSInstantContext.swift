/// A lightweight callback-facing context used for synchronous JavaScript interactions.
///
/// `JSInstantContext` mirrors the user-facing API surface of `JSContext` for callback code,
/// but avoids actor hops so callbacks can run in a tight synchronous path.
///
/// Design intent:
/// - Provide a lightweight substitute for `JSContext` inside callback-heavy code paths.
/// - Keep API semantics aligned with `JSContext` (`make*`, global property helpers,
///   `evaluateScript`, etc.).
///
/// Non-goals:
/// - It is not a generic low-level bridge layer.
/// - Backend/handle/raw-context orchestration should stay in backend adapters or
///   local call-site helpers unless it is part of this callback-facing API surface.
public typealias JSInstantContext = JSEngineInstantContext<JavaScriptCoreEngine>

extension JSEngineInstantContext where E == JavaScriptCoreEngine {
  init(ctx: JavaScriptCoreContextRef) {
    self.init(
      handle: JSBorrowedContextHandle<JavaScriptCoreEngine>(
        _opaqueHandle: JavaScriptCoreRawContext(borrowing: ctx)
      ))
  }

  public var globalContextRef: JavaScriptCoreGlobalContextRef {
    guard let rawContext: JavaScriptCoreRawContext = driverContextHandle.opaqueHandle() else {
      preconditionFailure("JSInstantContext has invalid context handle")
    }
    return rawContext.ref
  }
}

extension JSEngineInstantContext where E == JavaScriptCoreEngine {
  private func makeFunctionHandle(
    named name: String,
    callback: @escaping JSFunctionCallback
  ) -> JSValueHandle<JavaScriptCoreEngine> {
    guard let rawContext: JavaScriptCoreRawContext = driverContextHandle.opaqueHandle() else {
      preconditionFailure("JSInstantContext has invalid context handle")
    }
    let rawValue = JavaScriptCoreEngine.makeFunction(
      named: name,
      callback: callback,
      in: rawContext,
      functionClass: actorContext.functionClass.value
    )
    return JavaScriptCoreEngine.valueHandle(from: rawValue)
  }

  var globalObjectRef: JavaScriptCoreObjectRef {
    JavaScriptCoreEngine.globalObject(in: globalContextRef)!
  }

  var actorContext: JSContext {
    JSContext.borrow(ctx: globalContextRef)
  }

  public func withGlobalObject<R: ~Copyable>(_ body: (borrowing JSValue) -> R) -> R {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    return body(globalObject)
  }

  public func makeString(_ value: String) -> JSValue {
    guard let handle = JavaScriptCoreEngine.makeStringValueHandle(value, driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeString could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  func makeSymbol(_ value: String) -> JSValue {
    guard let handle = JavaScriptCoreEngine.makeSymbolValueHandle(value, driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeSymbol could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeNumber(_ value: Double) -> JSValue {
    guard let handle = JavaScriptCoreEngine.makeNumberValueHandle(value, driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeNumber could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSValue {
    makeNumber(Double(value))
  }

  public func makeBoolean(_ value: Bool) -> JSValue {
    guard
      let handle = JavaScriptCoreEngine.makeBooleanValueHandle(value, driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeBoolean could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeNull() -> JSValue {
    guard let handle = JavaScriptCoreEngine.makeNullValueHandle(driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeNull could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeUndefined() -> JSValue {
    guard let handle = JavaScriptCoreEngine.makeUndefinedValueHandle(driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeUndefined could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeObject() -> JSValue {
    switch JSResult.from(
      handleResult: JavaScriptCoreEngine.makeObjectResultHandle(driverContextHandle))
    {
    case .value(let value):
      return value
    case .exception(let exception):
      return exception
    }
  }

  public func makeArray() -> JSValue {
    switch JSResult.from(
      handleResult: JavaScriptCoreEngine.makeArrayResultHandle(driverContextHandle))
    {
    case .value(let value):
      return value
    case .exception(let exception):
      return exception
    }
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback
  ) -> JSValue {
    JSValue(handleValue: makeFunctionHandle(named: name, callback: callback))
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSFunctionCallback
  ) {
    let function = makeFunction(named: name, callback: callback)
    setGlobalProperty(function, forKey: name, with: attributes)
  }

  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let ownedKey = JSStringManaged(key)
    withGlobalObject { globalObject in
      globalObject.setProperty(value, forKey: ownedKey, with: attributes, in: self)
    }
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) {
    let ownedKey = JSStringManaged(key)
    withGlobalObject { globalObject in
      globalObject.setProperty(
        value, forKey: ownedKey, using: converter, with: attributes, in: self)
    }
  }

  public func getGlobalProperty(forKey key: String) -> JSValue {
    let ownedKey = JSStringManaged(key)
    return withGlobalObject { globalObject in
      globalObject.getProperty(forKey: ownedKey, in: self)
    }
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: String,
    using converter: C.Type
  ) -> C.SwiftType {
    let ownedKey = JSStringManaged(key)
    return withGlobalObject { globalObject in
      globalObject.getProperty(forKey: ownedKey, using: converter, in: self)
    }
  }

  public func deleteGlobalProperty(forKey key: String) {
    let ownedKey = JSStringManaged(key)
    withGlobalObject { globalObject in
      globalObject.deleteProperty(forKey: ownedKey, in: self)
    }
  }

  public func hasGlobalProperty(_ key: String) -> Bool {
    let ownedKey = JSStringManaged(key)
    return withGlobalObject { globalObject in
      globalObject.hasProperty(ownedKey, in: self)
    }
  }

  public func evaluateScript(_ script: String) -> JSResult {
    let scriptString = JSStringValue(script)
    return evaluateScript(scriptString, startingLineNumber: 1)
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    startingLineNumber: Int32 = 1
  ) -> JSResult where Script: JSString, Script: ~Copyable {
    .from(
      handleResult: JavaScriptCoreEngine.evaluateScriptResultHandle(
        script.string,
        driverContextHandle,
        sourceURL: nil,
        startingLineNumber: startingLineNumber
      ))
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult where Script: JSString, Script: ~Copyable {
    .from(
      handleResult: JavaScriptCoreEngine.evaluateScriptResultHandle(
        script.string,
        driverContextHandle,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      ))
  }

  public func evaluateScript<SourceURL>(
    _ script: String,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult where SourceURL: JSString, SourceURL: ~Copyable {
    .from(
      handleResult: JavaScriptCoreEngine.evaluateScriptResultHandle(
        script,
        driverContextHandle,
        sourceURL: sourceURL.string,
        startingLineNumber: startingLineNumber
      ))
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult {
    .from(
      handleResult: JavaScriptCoreEngine.evaluateScriptResultHandle(
        script,
        driverContextHandle,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      ))
  }

  public func evaluateScript<Script, SourceURL>(
    _ script: borrowing Script,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult
  where Script: JSString, Script: ~Copyable, SourceURL: JSString, SourceURL: ~Copyable {
    .from(
      handleResult: JavaScriptCoreEngine.evaluateScriptResultHandle(
        script.string,
        driverContextHandle,
        sourceURL: sourceURL.string,
        startingLineNumber: startingLineNumber
      ))
  }
}

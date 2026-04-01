public struct JSInstantContext: ~Copyable {
  public let globalContextRef: JavaScriptCoreGlobalContextRef

  init(ctx: JavaScriptCoreContextRef) {
    self.globalContextRef = ctx
  }
}

extension JSInstantContext {
  private func makeFunctionRawValue(
    named name: String,
    callback: @escaping JSValue.JSFunctionCallback
  ) -> JavaScriptCoreRawValue {
    JavaScriptCoreBackendDriver.makeFunction(
      named: name,
      callback: callback,
      in: driverContext,
      functionClass: actorContext.functionClass.value
    )
  }

  var driverContext: JavaScriptCoreRawContext {
    JavaScriptCoreRawContext(borrowing: globalContextRef)
  }

  var driverContextHandle: JSBorrowedContextHandle<JavaScriptCoreEngine> {
    JSBorrowedContextHandle<JavaScriptCoreEngine>(_opaqueHandle: driverContext)
  }

  var globalObjectRef: JavaScriptCoreObjectRef {
    JavaScriptCoreBackendDriver.globalObject(in: globalContextRef)!
  }

  var actorContext: JSContext {
    JSContext.borrow(ctx: globalContextRef)
  }

  public func withGlobalObject<R: ~Copyable>(_ body: (borrowing JSValue) -> R) -> R {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    return body(globalObject)
  }

  public func makeString(_ value: String) -> JSValue {
    guard let handle = JavaScriptCoreBackendDriver.makeStringValueHandle(value, driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeString could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  func makeSymbol(_ value: String) -> JSValue {
    guard let handle = JavaScriptCoreBackendDriver.makeSymbolValueHandle(value, driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeSymbol could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeNumber(_ value: Double) -> JSValue {
    guard let handle = JavaScriptCoreBackendDriver.makeNumberValueHandle(value, driverContextHandle)
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
      let handle = JavaScriptCoreBackendDriver.makeBooleanValueHandle(value, driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeBoolean could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeNull() -> JSValue {
    guard let handle = JavaScriptCoreBackendDriver.makeNullValueHandle(driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeNull could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeUndefined() -> JSValue {
    guard let handle = JavaScriptCoreBackendDriver.makeUndefinedValueHandle(driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeUndefined could not create handle")
    }
    return JSValue(handleValue: handle)
  }

  public func makeObject() -> JSValue {
    switch JSResult.from(
      handleResult: JavaScriptCoreBackendDriver.makeObjectResultHandle(driverContextHandle))
    {
    case .value(let value):
      return value
    case .exception(let exception):
      return exception
    }
  }

  public func makeArray() -> JSValue {
    switch JSResult.from(
      handleResult: JavaScriptCoreBackendDriver.makeArrayResultHandle(driverContextHandle))
    {
    case .value(let value):
      return value
    case .exception(let exception):
      return exception
    }
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSValue.JSFunctionCallback
  ) -> JSValue {
    JSValue(rawValue: makeFunctionRawValue(named: name, callback: callback))
  }

  func looselyEquals(_ lhs: borrowing JSValue, _ rhs: borrowing JSValue) -> Bool {
    JavaScriptCoreBackendDriver.valueEquals(lhs.ref, rhs.ref, in: globalContextRef)
  }

  func strictlyEquals(_ lhs: borrowing JSValue, _ rhs: borrowing JSValue) -> Bool {
    JavaScriptCoreBackendDriver.valueStrictEquals(lhs.ref, rhs.ref, in: globalContextRef)
  }

  func callFunction(
    _ function: borrowing JSValue,
    this thisValue: JSValueHandle<JavaScriptCoreEngine>?,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult {
    .from(
      handleResult: JavaScriptCoreBackendDriver.callFunctionHandle(
        function.valueHandle(in: self),
        this: thisValue,
        arguments: arguments,
        in: driverContextHandle
      ))
  }

  func constructFunction(
    _ constructor: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult {
    .from(
      handleResult: JavaScriptCoreBackendDriver.constructHandle(
        constructor.valueHandle(in: self),
        arguments: arguments,
        in: driverContextHandle
      ))
  }

  func getStringProperty(_ name: String, on object: borrowing JSValue) -> JSResult {
    .from(
      handleResult: JavaScriptCoreBackendDriver.getStringPropertyHandle(
        name,
        on: object.valueHandle(in: self),
        in: driverContextHandle
      ))
  }

  func setStringProperty(
    _ name: String,
    on object: borrowing JSValue,
    to value: borrowing JSValue,
    attributes: JSPropertyAttributes
  ) -> Bool {
    JavaScriptCoreBackendDriver.setStringPropertyHandle(
      name,
      on: object.valueHandle(in: self),
      to: value.valueHandle(in: self),
      in: driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  func toObject(_ value: borrowing JSValue) -> JSResult {
    .from(
      handleResult: JavaScriptCoreBackendDriver.toObjectHandle(
        value.valueHandle(in: self),
        in: driverContextHandle
      ))
  }

  func isArray(_ value: borrowing JSValue) -> Bool {
    JavaScriptCoreBackendDriver.isArrayHandle(
      value.valueHandle(in: self),
      in: driverContextHandle
    ) ?? false
  }

  func isDate(_ value: borrowing JSValue) -> Bool {
    JavaScriptCoreBackendDriver.isDateHandle(
      value.valueHandle(in: self),
      in: driverContextHandle
    ) ?? false
  }

  func isInstanceOf(_ value: borrowing JSValue, constructor: borrowing JSValue) -> Bool {
    JavaScriptCoreBackendDriver.isInstanceOfHandle(
      value.valueHandle(in: self),
      constructor: constructor.valueHandle(in: self),
      in: driverContextHandle
    ) ?? false
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSValue.JSFunctionCallback
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
      handleResult: JavaScriptCoreBackendDriver.evaluateScriptResultHandle(
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
      handleResult: JavaScriptCoreBackendDriver.evaluateScriptResultHandle(
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
      handleResult: JavaScriptCoreBackendDriver.evaluateScriptResultHandle(
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
      handleResult: JavaScriptCoreBackendDriver.evaluateScriptResultHandle(
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
      handleResult: JavaScriptCoreBackendDriver.evaluateScriptResultHandle(
        script.string,
        driverContextHandle,
        sourceURL: sourceURL.string,
        startingLineNumber: startingLineNumber
      ))
  }
}

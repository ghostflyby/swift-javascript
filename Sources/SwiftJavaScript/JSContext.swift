public actor JSContext<E: JSEngine> {
  nonisolated package let driverContextHandle: E.ContextHandle
  public let virtualMachine: JSVirtualMachine<E>
  nonisolated public let unownedExecutor: UnownedSerialExecutor

  public init() {
    self.init(virtualMachine: JSVirtualMachine<E>())
  }

  public init(virtualMachine: JSVirtualMachine<E>) {
    guard
      let driverContextHandle = E.makeBorrowedContextHandleFromRuntime(
        in: virtualMachine.driverRuntimeHandle)
    else {
      preconditionFailure("JSContext could not create context handle from runtime")
    }

    self.init(virtualMachine: virtualMachine, driverContextHandle: driverContextHandle)
    self.driverContextHandle.bindContextOwner(self)
  }

  package init(
    virtualMachine: JSVirtualMachine<E>,
    driverContextHandle: E.ContextHandle
  ) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    self.driverContextHandle = driverContextHandle
  }

  deinit {
    _ = driverContextHandle.releaseReference()
  }
}

extension JSContext {
  public func withIsolatedGlobalObject<R: Sendable>(
    _ body:
      @Sendable (
        isolated JSContext<E>,
        borrowing JSValue<E>
      ) -> R
  ) -> R {
    withGlobalObject { globalObject in
      body(self, globalObject)
    }
  }

  public func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSInstantContext<E>) throws(Failure) -> R
  ) throws(Failure) -> R {
    let instantContext = JSInstantContext<E>(context: self)
    return try body(instantContext)
  }

  @inline(__always)
  @_lifetime(borrow self)
  private func valueFromHandle(
    _ handle: JSValueHandle<E>?,
    _ failureMessage: StaticString
  ) -> JSValue<E> {
    guard let handle else {
      preconditionFailure(String(describing: failureMessage))
    }
    return JSValue(handleValue: handle)
  }

  @inline(__always)
  @_lifetime(borrow self)
  private func valueFromResultHandle(
    _ handleResult: consuming JSResult<JSValueHandle<E>>?
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(handleResult)
    switch consume result {
    case .value(let value):
      return value
    case .exception(let exception):
      return exception
    }
  }

  @_lifetime(borrow self)
  public func makeString(_ value: String) -> JSValue<E> {
    valueFromHandle(
      E.makeStringValueHandle(value, driverContextHandle),
      "JSContext.makeString could not create handle"
    )
  }

  @_lifetime(borrow self)
  public func makeNumber(_ value: Double) -> JSValue<E> {
    valueFromHandle(
      E.makeNumberValueHandle(value, driverContextHandle),
      "JSContext.makeNumber could not create handle"
    )
  }

  @_lifetime(borrow self)
  public func makeNumber(_ value: some BinaryInteger) -> JSValue<E> {
    makeNumber(Double(value))
  }

  @_lifetime(borrow self)
  public func makeBoolean(_ value: Bool) -> JSValue<E> {
    valueFromHandle(
      E.makeBooleanValueHandle(value, driverContextHandle),
      "JSContext.makeBoolean could not create handle"
    )
  }

  @_lifetime(borrow self)
  public func makeNull() -> JSValue<E> {
    valueFromHandle(
      E.makeNullValueHandle(driverContextHandle),
      "JSContext.makeNull could not create handle"
    )
  }

  @_lifetime(borrow self)
  public func makeUndefined() -> JSValue<E> {
    valueFromHandle(
      E.makeUndefinedValueHandle(driverContextHandle),
      "JSContext.makeUndefined could not create handle"
    )
  }

  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    withInstantContext { instantContext in
      instantContext.withGlobalObject(body)
    }
  }

  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    withInstantContext { instantContext in
      instantContext.setGlobalProperty(value, forKey: key, with: attributes)
    }
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) {
    withInstantContext { instantContext in
      instantContext.setGlobalProperty(value, forKey: key, using: converter, with: attributes)
    }
  }

  @_lifetime(borrow self)
  public func getGlobalProperty(forKey key: String) -> JSValue<E> {
    let globalObject = valueFromHandle(
      E.globalObjectValueHandle(driverContextHandle),
      "JSContext.getGlobalProperty could not read global object"
    )
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getStringPropertyHandle(
        key,
        on: globalObject.borrowHandle(),
        in: driverContextHandle
      ))
    switch consume result {
    case .value(let value):
      return value
    case .exception:
      return makeUndefined()
    }
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: String,
    using converter: C.Type
  ) -> C.SwiftType {
    withInstantContext { instantContext in
      instantContext.getGlobalProperty(forKey: key, using: converter)
    }
  }

  public func deleteGlobalProperty(forKey key: String) {
    withInstantContext { instantContext in
      instantContext.deleteGlobalProperty(forKey: key)
    }
  }

  public func hasGlobalProperty(_ key: String) -> Bool {
    withInstantContext { instantContext in
      instantContext.hasGlobalProperty(key)
    }
  }

  @_lifetime(borrow self)
  public func makeObject() -> JSValue<E> {
    valueFromResultHandle(E.makeObjectResultHandle(driverContextHandle))
  }

  @_lifetime(borrow self)
  public func makeArray() -> JSValue<E> {
    valueFromResultHandle(E.makeArrayResultHandle(driverContextHandle))
  }

  @_lifetime(borrow self)
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<E>
  ) -> JSValue<E> where E.Engine == E {
    valueFromHandle(
      E.makeFunctionValueHandle(
        named: name,
        callback: retainedFunctionCallback(callback),
        in: driverContextHandle
      ),
      "JSContext.makeFunction could not create handle"
    )
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSFunctionCallback<E>
  ) where E.Engine == E {
    withInstantContext { instantContext in
      instantContext.installGlobalFunction(named: name, with: attributes, callback: callback)
    }
  }

  @_lifetime(borrow self)
  public func evaluateScript(_ script: String) -> JSResult<JSValue<E>> {
    bridgeHandleResult(
      E.evaluateScriptResultHandle(
        script,
        driverContextHandle,
        sourceURL: nil,
        startingLineNumber: 1
      ))
  }

  @_lifetime(borrow self)
  public func evaluateScript<Script>(
    _ script: borrowing Script,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where Script: JSString, Script: ~Copyable {
    bridgeHandleResult(
      E.evaluateScriptResultHandle(
        script.string,
        driverContextHandle,
        sourceURL: nil,
        startingLineNumber: startingLineNumber
      ))
  }

  @_lifetime(borrow self)
  public func evaluateScript<Script>(
    _ script: borrowing Script,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where Script: JSString, Script: ~Copyable {
    evaluateScript(
      script.string,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }

  @_lifetime(borrow self)
  public func evaluateScript<SourceURL>(
    _ script: String,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where SourceURL: JSString, SourceURL: ~Copyable {
    evaluateScript(
      script,
      sourceURL: sourceURL.string,
      startingLineNumber: startingLineNumber
    )
  }

  @_lifetime(borrow self)
  public func evaluateScript(
    _ script: String,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    bridgeHandleResult(
      E.evaluateScriptResultHandle(
        script,
        driverContextHandle,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      ))
  }

  @_lifetime(borrow self)
  public func evaluateScript<Script, SourceURL>(
    _ script: borrowing Script,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>>
  where Script: JSString, Script: ~Copyable, SourceURL: JSString, SourceURL: ~Copyable {
    evaluateScript(
      script.string,
      sourceURL: sourceURL.string,
      startingLineNumber: startingLineNumber
    )
  }
}

extension JSContext: Equatable where E.ContextHandle: Equatable {
  nonisolated public static func == (lhs: JSContext<E>, rhs: JSContext<E>) -> Bool {
    lhs.driverContextHandle == rhs.driverContextHandle
  }
}

extension JSContext: Hashable where E.ContextHandle: Hashable {
  nonisolated public func hash(into hasher: inout Hasher) {
    hasher.combine(driverContextHandle)
  }
}
